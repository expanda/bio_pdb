package Bio::PDB::Util::ResTable;
use strict;
use warnings;
use Carp qw{carp croak};
use base qw{Class::Accessor::Fast};

__PACKAGE__->mk_accessors(qw{table_to3 table_to1});

sub new {
    my $class = shift;
    my $seqadv = shift;
    my $self = bless {}, $class;
    $self->_load_default_table;
    $self->_load_seqadv($seqadv) if ($seqadv);
    return $self;
}

sub _load_default_table {#{{{
    my $self = shift;
    $self->table_to3({
            'G' => 'GLY',
            'A' => 'ALA',
            'S' => 'SER',
            'T' => 'THR',
            'V' => 'VAL',
            'L' => 'LEU',
            'I' => 'ILE',
            'D' => 'ASP',
            'E' => 'GLU',
            'N' => 'ASN',
            'Q' => 'GLN',
            'K' => 'LYS',
            'R' => 'ARG',
            'C' => 'CYS',
            'M' => 'MET',
            'F' => 'PHE',
            'Y' => 'TYR',
            'W' => 'TRP',
            'H' => 'HIS',
            'P' => 'PRO',
        });
    $self->table_to1({
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
        });
}#}}}

sub _load_seqadv {
    my $self = shift;
    my $seqadv = shift;

    for my $adv (@{$seqadv->rows}) {
        if (
            ( ! defined $self->table_to1->{$adv->res_name} ) and
            defined $adv->seq_num and defined $adv->db_seq and
            $adv->seq_num == $adv->db_seq
        ) {
            $self->table_to1->{$adv->res_name} = $self->table_to3->{$adv->db_res};
        }
    }
}

sub to_3 {
    my $self = shift;
    my $res = shift;

    unless ($self->table_to3->{uc $res}) {
        return undef;
    }
    else {
        return $self->table_to3->{uc $res};
    }
}

sub to_1 {
    my $self = shift;
    my $res = shift;

    unless ($self->table_to1->{uc $res}) {
        return undef;
    }
    else {
        return $self->table_to1->{uc $res};
    }
}

1;
