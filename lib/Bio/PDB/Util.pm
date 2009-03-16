package Bio::PDB::Util;
use strict;
use warnings;
use Carp qw{carp croak};

sub to_3 {
    my $this = shift;
    my $res = shift;
    my $map = {
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
    };
	 unless ($map->{uc $res}) {
		 #carp "There is no Entry : $res";
		 return undef;
	 }
	 else {
		 return $map->{uc $res};
	 }
}

sub to_1 {
    my $this = shift;
    my $res = shift;
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
	 unless ($map->{uc $res}) {
#		 carp "There is no Entry : $res";
		 return undef;
	 }
	 else {
		 return $map->{uc $res};
	 }
}

1;
