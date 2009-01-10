package Bio::PDB::DB::File;
use base qw{Bio::PDB::DB};
use strict;
use warnings;
use File::Spec;
use File::Util;
use File::Path;
use IO::Uncompress::Gunzip qw(gunzip $GunzipError);
use Carp qw{croak confess carp};

#===============================================================================
#    FILE:  File.pm
#  AUTHOR:  Hiroyuki Nakamura <hiroyuki@sfc.keio.ac.jp>
# VERSION:  1.0
# CREATED:  2009/01/09 17時10分14秒 JST
# TODO :
#         * obsolete and model check.
#         * Log4Perl in $this->logger
#===============================================================================

__PACKAGE__->mk_accessors( qw{pdb_dir model_dir obsolete_dir cache_dir deflater logger} );

#{{{ new : constructor
sub new { 
    my ($class) = shift;
    my $options = {
        pdb_dir      => '',
        model_dir    => '',
        obsolete_dir => '',
        cache_dir    => '', # tmp file directory
        @_
    };

    my $this = bless {}, $class;

    $this->pdb_dir($options->{'pdb_dir'});
    $this->model_dir($options->{'model_dir'});
    $this->cache_dir($options->{'cache_dir'});
    $this->obsolete_dir($options->{'obsolete_dir'});

    $this->init_database();

    $this->init_cache;

    return $this;
}
#}}}
#{{{ File Cashing 
{
    my $caches = {};
    my ( $current_cache_size , $max_cache_size ) = ( 0 , 0 );
    my ( $lxs , $mountpoint );
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
                push @candidates, $info->{mountpoint} if ($this->cache_dir =~ /^$$info{mountpoint}/);
            }
            $mountpoint = (sort { length($b) <=> length($a) } @candidates)[0];
            $max_cache_size = $diskinfo->{$mountpoint}->{free} - 100000; # leave 10MB.
        }
        return 1;
    }
#}}}
#{{{ get_cache : get PDB file as filehandle.
    sub get_cache {
        my $this = shift;
        my $id = shift;
        open my $fh , $caches->{$id} || croak "Failed to open file. : $!";
        return $fh;
    }
#}}}
#{{{ set_cache : set PDB File to cache direcotry
    sub set_cache {
        my $this = shift;
        my ($id, $fh) = shift;

        check_disk_usage();

        my $dir = $this->directory_name_for($id);
        my $file_path = File::Spec->join($this->cache_dir, $dir, $this->file_name_for($id));

        unless (-d ${[File::Spec->splitpath($file_path)]}[1]) {
            mkpath($file_path, {error => \my $err});
            for my $diag (@$err) {
                my ($f, $m)  = each %$diag;
                print "Failed to make directory : $m\n" if $f eq '';
            }
        }

        open my $out, ">$file_path" || croak "Failed to open file. : $!";
        print $out while ( <$fh> );
        $caches->{$id} = $file_path;

        # reload cache status
        $current_cache_size += ( stat ( $file_path ))[7];
        
        return 1;
    }
#}}}
#{{{ exists_in_cache : test id exists in cache.
    sub exists_in_cache {
        my $this = shift;
        return ( defined $caches->{+(shift)} );
    }
#}}}
#{{{ check_disk_usage : check disk usage and decrease filecache.
    sub check_disk_usage {
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
    sub _clear_cache {
       while (my ($id, $path) = each %{$caches} ){
        unlink $path; 
       };
       undef $caches;
       return 1;
    }
}
#}}}
# get_as_object : get PDB data. #{{{
sub get_as_object {
    my $this = shift;
    my $id = shift;
    my %args_pdb = @_;

    if ($this->exists_in_cache($id)) {
        return Bio::PDB->new($this->get_cache($id), %args_pdb);
    }
    else {
        my $dir = $this->directory_name_for($id);
        my $archive_path = File::Spec->join($this->pdb_dir, $dir, $this->archive_name_for($id));
        my $file_path    = File::Spec->join($this->cache_dir, $dir, $this->file_name_for($id));

        my $fh;
        for my $category ( $this->archive_dir, $this->model_dir, $this->obsolete_dir ) {
            my $path = File::Spec->join( $category, $dir, $this->archive_name_for($id));
            if (-f $path) {
                $fh = IO::Uncompress::Gunzip->new($path) || die "$GunzipError $!";
                last;
            }
        }

        if ($fh) {
            $this->set_cache($id, $fh);
            return Bio::PDB->new($fh, %args_pdb);       
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
    my $id = shift;

    if ($this->exists_in_cache($id)) {
        return $this->get_cache($id);
    }
    else {
        my $dir = $this->directory_name_for($id);
        my $archive_path = File::Spec->join($this->pdb_dir, $dir, $this->archive_name_for($id));
        my $fh = IO::Uncompress::Gunzip->new($archive_path) || die "$GunzipError";
        $this->set_cache($id, $fh);
        return $fh;
    }
}
#}}}
#{{{ init_database : initialization of database
sub init_database {
    my $this = shift;

    {
        no strict 'refs';

        for my $dir (qw{pdb_dir model_dir obsolete_dir cache_dir}) {
            unless (-d $this->$dir) {
                croak $! unless (mkdir $this->$dir);
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
