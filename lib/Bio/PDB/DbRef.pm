package Bio::PDB::DBREF;

use strict;
use warnings;
use Data::Dumper;
use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(
    qw{ idcode chain_id seq_begin insert_begin 
    seq_end insert_end database db_accession
    db_id_code dbseq_begin dbins_begin dbseq_end dbins_end}
);

sub new {
    my ($class, $annotations) = @_;
    my $annotation = shift @{$annotations};
    my $string = (ref $annotation) ? $annotation->tagname . "  ". $annotation->value : $annotation;
    my $this = bless {}, $class;
    return $this unless $string;
    my $tmp;
    my $fields = {
        idcode       => [7, 4],
        chain_id     => [12, 1],
        seq_begin    => [14, 4],
        insert_begin => [18, 1],
        seq_end      => [20, 4],
        insert_end   => [24, 1],
        database     => [26, 6],
        db_accession => [33, 8],
        db_id_code   => [42, 12],
        dbseq_begin  => [55, 5],
        dbins_begin  => [60, 1],
        dbseq_end    => [62, 5],
        dbins_end    => [67, 1],
    };

    {
        no strict 'refs';
        while ( my( $field, $substr) = each %{$fields} ) {
            $tmp = substr $string, $substr->[0], $substr->[1];
            $tmp =~ tr/ //d;
            $this->$field($tmp);
        }
    }

    return $this;
}

1;


__END__

=head1 NAME PDB::DBREF

=head1 DESCRIPTION

    COLUMNS       DATA TYPE     FIELD              DEFINITION
    -----------------------------------------------------------------------------------
    1 -  6       Record name   "DBREF "
    8 - 11       IDcode        idCode              ID code of this entry.
    13            Character     chainID            Chain  identifier.
    15 - 18       Integer       seqBegin           Initial sequence number of the
                                                   PDB sequence segment.
    19            AChar         insertBegin        Initial  insertion code of the 
                                                   PDB  sequence segment.
    21 - 24       Integer       seqEnd             Ending sequence number of the
                                                   PDB  sequence segment.
    25            AChar         insertEnd          Ending insertion code of the
                                                   PDB  sequence segment.
    27 - 32       LString       database           Sequence database name. 
    34 - 41       LString       dbAccession        Sequence database accession code.
    43 - 54       LString       dbIdCode           Sequence  database identification code.
    56 - 60       Integer       dbseqBegin         Initial sequence number of the
                                                   database seqment.
    61            AChar         idbnsBeg           Insertion code of initial residue of the
                                                   segment, if PDB is the reference.
    63 - 67       Integer       dbseqEnd           Ending sequence number of the
                                                   database segment.
    68            AChar         dbinsEnd           Insertion code of the ending residue of
                                                   the segment, if PDB is the reference.

=cut
