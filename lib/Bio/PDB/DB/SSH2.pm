package Bio::PDB::DB::SSH2;

use base qw{Bio::PDB::DB::File};

use strict;
use warnings;
use NEXT;

use Net::SSH2;
use Path::Class qw{file};
use Carp qw{croak confess carp};
use Bio::PDB;

use Data::Dumper;

#===============================================================================
#    FILE:  SSH2.pm
#  AUTHOR:  Hiroyuki Nakamura <hiroyuki@sfc.keio.ac.jp>
# VERSION:  1.0
# CREATED:  2009/01/09 17時05分28秒 JST
# DESCRIPTION: PDB Database Interface.
#===============================================================================

__PACKAGE__->mk_accessors(qw{connection cache remote_dir cache_dir pdb_dir});

sub new { #{{{
    my ($class) = shift;
    my $options = {
        host         => '',
        user         => '',
        port         => '',
        private_key  => '',
        remote_dir   => '',
        local_dir    => '',
        @_
    };

    croak "Required options : host, user, private_key"
    if ! $options->{host} or ! $options->{user} or ! $options->{private_key};

    my $self = bless {}, $class;

    $self->connection(Net::SSH2->new);
    $self->connection->connect($options->{host})
        or croak "Connection establish failed. :$!";

    $self->connection->auth_publickey(
        $options->{user},
        "$options->{private_key}.pub",
        $options->{private_key}) or confess "Authentification faild.";

    $self->remote_dir($options->{remote_dir});
    $self->cache_dir(Path::Class::Dir->new($options->{local_dir}, 'cache'));
    $self->pdb_dir(Path::Class::Dir->new($options->{local_dir}, 'archive'));

    $self->init_cache; # TODO : to use $self->NEXT::new()

    return $self;
}
#}}}
sub get_as_object {#{{{
    my $self = shift;
    $self->_scp_to_local($_[0]);
    return $self->NEXT::get_as_object( @_ );
}
#}}}
sub get_as_filehandle {#{{{
    my $self = shift;
    $self->_scp_to_local($_[0]);
    return $self->NEXT::get_as_object( @_ );
}
#}}}
sub _scp_to_local {#{{{
    my $self = shift;
    my $id = shift;

    my $local_filepath =  Path::Class::File->new(
        $self->pdb_dir,
        $self->directory_name_for($id),
        $self->archive_name_for($id)
    );

    return 1 if -e $local_filepath;

    my $remote_filepath = Path::Class::File->new(
        $self->remote_dir,
        $self->directory_name_for($id),
        $self->archive_name_for($id)
    );

    $local_filepath->parent->mkpath() unless -e $local_filepath ;

    print "$remote_filepath -> $local_filepath\n";

    $self->connection->scp_get(
        $remote_filepath->stringify,
        $local_filepath->stringify,
    );

    return 1;
}
#}}}
#sub DESTROY {
#    my $self = shift;
#    $self->connection->disconnect;
#}

1;

__END__

=head1 NAME

Bio::PDB::DB::SSH2 - network store databaese object for Protein Data Bank

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
