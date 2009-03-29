package Bio::PDB::DB::File;
use base qw{Bio::PDB::DB};
use strict;
use warnings;
use File::Spec;
use File::Util;
use File::Path;
use File::Find;
#use Cache::MemoryCache;
use Bio::PDB;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Carp qw{croak confess carp};
use Data::Dumper;

#===============================================================================
#    FILE:  File.pm
#  AUTHOR:  Hiroyuki Nakamura <hiroyuki@sfc.keio.ac.jp>
# VERSION:  1.0
# CREATED:  2009/01/09 17時10分14秒 JST
# TODO :
#         * Log4Perl in $this->logger -> to DB/Logger.pm
# DONE :
#         * obsolete and model check.
#===============================================================================

__PACKAGE__->mk_accessors(
    qw{pdb_dir model_dir obsolete_dir cache_dir logger}
);

#{{{ new : constructor
sub new {
    my ($class) = shift;
    my $options = {
        pdb_dir      => '',
        model_dir    => '',
        obsolete_dir => '',
        cache_dir    => '/tmp/pdb', # tmp file directory
        @_
    };

    my $this = bless {}, $class;

    $this->pdb_dir($options->{'pdb_dir'});
    $this->model_dir($options->{'model_dir'});
    $this->cache_dir($options->{'cache_dir'});
    $this->obsolete_dir($options->{'obsolete_dir'});

    $this->init_database();

    $this->init_cache;

#	 my $cache = new Cache::MemoryCache();
#	 $this->memorycache($cache);
    return $this;
}
#}}}
#{{{ File Cashing 
{
    my $caches = {};
    my ( $current_cache_size , $max_cache_size ) = ( 0 , 0 );
    my ( $lxs , $diskname );
#{{{ init_cache : initialize max_cache_size.
    sub init_cache {
        my $this = shift;
        eval { require Sys::Statistics::Linux::DiskUsage; };
        if ($@) {
            $max_cache_size = 900000;
        }
        else {
            $lxs = Sys::Statistics::Linux::DiskUsage->new();
            my $diskinfo = $lxs->get();
            my @candidates;
            while (my ($disk, $info) = each %{$diskinfo}) {
                push @candidates, { disk => $disk, mp => $info->{mountpoint}} if ($this->cache_dir =~ /^$$info{mountpoint}/);
            }
            $diskname = (sort { length($b->{mp}) <=> length($a->{mp}) } @candidates)[0]->{disk};
            $max_cache_size = $diskinfo->{$diskname}->{free} * 1000 - 100000; # leave 10MB.
        }
        return 1;
    }
#}}}
#{{{ get_cache : get PDB file as filehandle.
    sub get_cache {
        my $this = shift;
        my $id = shift;
        open my $fh, $caches->{$id} || croak "Failed to open file. : $!";
        return $fh;
    }
#}}}
#{{{ set_cache : set PDB File to cache direcotry
    sub set_cache {
        my $this = shift;
        my ($id, $infh) = @_;

        check_disk_usage();

        my $dir = $this->directory_name_for($id);
        my $file_path = File::Spec->join($this->cache_dir, $dir, $this->file_name_for($id));

        unless (-d ${[File::Spec->splitpath($file_path)]}[1]) {
            mkpath(${[File::Spec->splitpath($file_path)]}[1], {error => \my $err});
            for my $diag (@$err) {
                my ($f, $m)  = each %$diag;
                print STDERR "Failed to make directory : $m\n" if $f eq '';
            }
        }

        #print "Cache to $file_path\n";
        #print Dumper $infh;

        open my $out, ">$file_path" or croak "Failed to open file. : $!";
        print $out $_ while (<$infh>);
        $caches->{$id} = $file_path;
        close $out;
        close $infh;
        # reload cache status
        $current_cache_size += ( stat ( $file_path ))[7];
        open my $returnfh, $file_path or croak "Failed to open file. : $!";
        return $returnfh;
    }
#}}}
#{{{ exists_in_cache : test id exists in cache.
    sub exists_in_cache {
        my $this = shift;
        my $id = shift;
        if (defined $caches->{$id}) {
            return 1; 
        }
        else {
            my $cache_path = File::Spec->join($this->cache_dir, $this->directory_name_for($id) , $this->file_name_for($id));
            #print "Find : $cache_path\n";
            if (-f $cache_path) {
                $caches->{$id} = $cache_path;
                return 1;
            }
        }
        return 0;
    }
#}}}
#{{{ check_disk_usage : check disk usage and decrease filecache.
    sub check_disk_usage {
        print STDERR "MAX : $max_cache_size\tCUR : $current_cache_size\n";
        if ( $max_cache_size * 0.95 < $current_cache_size ) {
            my $number_of_remove_files = 10;
            for my $id (( keys %{$caches} )[1..$number_of_remove_files]) {
                unlink $caches->{$id};
                delete $caches->{$id};
            }       
        }
        return 1;
    }
#}}}
    sub clear_cache {
        my $this = shift;
        while (my ($id, $path) = each %{$caches} ){
            unlink $path;
        };
        #find(sub{ if ( -d $_ && $_ !~ /^\.{1,2}$/ ) {rmdir $_ || croak "clear_cache : $!";} }, $this->cache_dir );
        undef $caches;
        return 1;
    }
}
#}}}
# get_as_object : get PDB data. #{{{
sub get_as_object {
    my $this = shift;
    my $id = lc shift;
    my %args_pdb = @_;


    if ($this->exists_in_cache($id)) {
        my $obj;
        eval { $obj = Bio::PDB->new_from_filehandle($this->get_cache($id), %args_pdb);};
        if ($@) {
            my $dir = $this->directory_name_for($id);
            my $archive_path = File::Spec->join($this->pdb_dir, $dir, $this->archive_name_for($id));
            my $fh;
            for my $category ( $this->pdb_dir, $this->model_dir, $this->obsolete_dir ) {
                my $path = File::Spec->join( $category, $dir, $this->archive_name_for($id));
                if (-f $path) {
                    $fh = IO::Uncompress::Gunzip->new($path) or die "GunzipError : $GunzipError";
                    last;
                }
            }
            $obj = Bio::PDB->new_from_filehandle($fh, %args_pdb); 
        }
        return $obj;
    }
    else {
        my $dir = $this->directory_name_for($id);
        my $archive_path = File::Spec->join($this->pdb_dir, $dir, $this->archive_name_for($id));
        my $file_path    = File::Spec->join($this->cache_dir, $dir, $this->file_name_for($id));

        my $fh;
        for my $category ( $this->pdb_dir, $this->model_dir, $this->obsolete_dir ) {
            my $path = File::Spec->join( $category, $dir, $this->archive_name_for($id));
            if (-f $path) {
                $fh = IO::Uncompress::Gunzip->new($path) or die "GunzipError : $GunzipError";
                last;
            }
        }

        if ($fh) {
            my $newfh = $this->set_cache($id, $fh);
            my $obj;
            eval{ $obj = Bio::PDB->new_from_filehandle($newfh, %args_pdb);};
            if ($@) {
                carp qq{$@};	
                my $gzfh;
                for my $category ( $this->pdb_dir, $this->model_dir, $this->obsolete_dir ) {
                    my $path = File::Spec->join( $category, $dir, $this->archive_name_for($id));
                    if (-f $path) {
                        $gzfh = IO::Uncompress::Gunzip->new($path) or die "GunzipError : $GunzipError";
                        last;
                    }
                }
                $obj = Bio::PDB::->new_from_filehandle($gzfh, %args_pdb);
            }
            close $newfh;
            return $obj;
        }
        else {
            return 0;
        }
    }
}
#}}}
#{{{ get_as_filehandle : get PDB data as filehandle.
sub get_as_filehandle {
    my $this = shift;
    my $id = lc shift;

    if ($this->exists_in_cache($id)) {
        print STDERR "get from cache\n";
        return $this->get_cache($id);
    }
    else {
        #print "get from archive\n";
        my $dir = $this->directory_name_for($id);

        my $fh;
        for my $category ( $this->pdb_dir, $this->model_dir, $this->obsolete_dir ) {
            my $path = File::Spec->join( $category, $dir, $this->archive_name_for($id));
            if (-f $path) {
                $fh = IO::Uncompress::Gunzip->new($path) or die "GunzipError : $GunzipError";
                last;
            }
        }

        if ($fh) {
            return $this->set_cache($id, $fh);
        }
        else {
            return 0;
        }

    }
}
#}}}
#{{{ init_database : initialization of database
sub init_database {
    my $this = shift;

    {
        no strict 'refs';

        for my $dir (qw{pdb_dir model_dir obsolete_dir cache_dir}) {
            my $dpath = $this->$dir;
            next if ! defined $dpath or $dpath =~ /(?:^\s|^$)/;
            unless ( -d $this->$dir ) {
                croak "init_database :[$dpath]  $!" unless (mkdir $this->$dir);
            }
        }
    }

    return 1;
}
#}}}
# sub download : download PDB datas #{{{
#
# RSYNC=/usr/bin/rsync  # location of local rsync
#
# # You should NOT CHANGE THE NEXT TWO LINES
#
# SERVER=rsync.wwpdb.org                               # remote server name
# PORT=33444                                           # port remote server is using
#
# ${RSYNC} -rlpt -v -z --delete --port=$PORT $SERVER::ftp_data/structures/divided/pdb/ $MIRRORDIR > $LOGFILE 3>/dev/null
# ${RSYNC} -rlpt -v -z --delete --port=$PORT $SERVER::ftp_data/structures/obsolete/pdb/ $OBSOLETE > $LOGFILE 2>/dev/null
# ${RSYNC} -rlpt -v -z --delete --port=$PORT $SERVER::ftp_data/structures/models/current/ $THEORITICAL > $LOGFILE 2>/dev/null
sub download {
    my $this = shift;
    my $rsync = qx/which rsync/;
    my $opt = { server => 'rsync.wwpdb.org', port => 33444, @_};
    chomp $rsync ;
    my ( $server , $port ) = ( $opt->{server}, $opt->{port} );

    my ( $pdb , $obsolete, $model ) = ($this->pdb_dir, $this->obsolete_dir, $this->model_dir );
    print STDERR qq{Download PDB data to $pdb. \n This downlaod take a long time ... \n};
    qx[$rsync -rlpt -v -z --delete --port=$port ${server}::ftp_data/structures/divided/pdb/ $pdb 2>/dev/null];
    print STDERR qq{Download PDB-obsolete data to $obsolete. \n This downlaod take a long time ... \n};
    qx[$rsync -rlpt -v -z --delete --port=$port ${server}::ftp_data/structures/obsolete/pdb/ $obsolete 2>/dev/null/];
    print STDERR qq{Download PDB-model data to $model. \n This downlaod take a long time ... \n};
    qx[$rsync -rlpt -v -z --delete --port=$port ${server}::ftp_data/structures/models/current/ $model 2>/dev/null];

    return 1;
}

#}}}

1;

__END__

=head1 NAME

Bio::PDB::DB::File - File store databaese object for Protein Data Bank

=head1 DESCRIPTION

Description here.

=head1 Methods

=head2 new

=head2 get_as_object

=head2 get_as_filehandle

=head2 init_database

=head2 download

=head1 Author

Hiroyuki Nakamura 

=cut

