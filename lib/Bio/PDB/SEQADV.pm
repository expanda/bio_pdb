package Bio::PDB::SEQADV;
use strict;
use warnings;
use base qw{Class::Accessor::Fast};
use Data::Dumper;
__PACKAGE__->mk_accessors(qw{text rows});

sub new {
    my ($class, $annotations) = @_;
    my @rows;
    my $annotation = shift @{$annotations};
    my $string = (ref $annotation) ? $annotation->value : $annotation;
    my $this = bless {}, $class;
    my $i=0;
    while (my $l = substr $string, $i, 63) {
        push @rows , Bio::PDB::SEQADV::Row->new($l);
        $i += 63;
    }
    $this->rows(\@rows);
    return $this;
}

sub insert_before {
    my $this = shift;
    my $chain = shift || "A";
    my $before_base;

    for ( $this->adv_for($chain) ) {
        my $insert_at = $_->seq_num;
        #print "$insert_at\n";
        if ($insert_at <= 0) {
            $before_base .= $_->residue;
        }
    }

    return $before_base;
}

sub adv_for {
    my $this = shift;
    my $chain = shift || "A";
    return  grep { $_->chain_id eq $chain } @{$this->rows};
}

# sub insertion_start {
#     my $this = shift;
#     my $chain = shift || "A";
#     my @rows_for_chain = map { $_->chain_id eq $chain } $this->rows;
# }

package Bio::PDB::SEQADV::Row;
use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(qw{idcode res_name chain_id seq_num i_code database db_id_code db_res db_seq conflict});

sub new {
    my ($class, $string) = @_;
    my $this = bless {}, $class;
    my $tmp;
    my $fields = {
        idcode       => [0, 4],
        res_name     => [5, 3],
        chain_id     => [9, 1],
        seq_num      => [11, 4],
        i_code       => [15, 1],
        database     => [17, 4],
        db_id_code   => [22, 9],
        db_res       => [32, 3],
        db_seq       => [36, 4],
        conflict     => [42, 21],
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

sub residue {
    my $this = shift;
    my $map = {
        GLY => 'G',
        ALA => 'A',
        SER => 'S',
        THR => 'T',
        VAL => 'V',
        LEU => 'L',
        ILE => 'I',
        ASP => 'D',
        GLU => 'E',
        ASN => 'N',
        GLN => 'Q',
        LYS => 'K',
        ARG => 'R',
        CYS => 'C',
        MET => 'M',
        PHE => 'F',
        TYR => 'Y',
        TRP => 'W',
        HIS => 'H',
        PRO => 'P',
    };
    return $map->{uc $this->res_name};
}
1;
