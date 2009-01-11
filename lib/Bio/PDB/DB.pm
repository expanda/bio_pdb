package Bio::PDB::DB;
use strict;
use warnings;
use Carp qw{croak confess carp};
#===============================================================================
#    FILE:  DB.pm
#  AUTHOR:  Hiroyuki Nakamura <hiroyuki@sfc.keio.ac.jp>
# VERSION:  1.0
# CREATED:  2009/01/09 17時05分28秒 JST
# DESCRIPTION: PDB Database Interface.
#===============================================================================
use base qw{Class::Accessor::Fast};

sub new {

}

sub init_database {
    carp "[ Please Implement. ]";
}

sub get_as_object {
    carp "[ Please Implement. ]";
}

sub get_as_filehandle {
    carp "[ Please Implement. ]";
}

sub create_random_id {
    my $this = shift;
    my $id = int(rand 4);
    $id .= ( rand( 10 ) > 5 ) ? chr(48 + rand(9)) : chr((97 + rand(25))) for 0..2;
    return $id
}

sub directory_name_for {
    my $this = shift;
    my $id = lc shift;
    return substr($id, 1, 2);
}

sub file_name_for {
    my $this = shift;
    my $id = lc shift;
    return qq[pdb${id}.ent];
}

sub archive_name_for {
    my $this = shift;
    my $id = lc shift;
    return qq[pdb${id}.ent.gz];
}

1;
