package Bio::PDB::ASA;

use strict;
use warnings;
use Carp qw{croak carp};
use base qw{Class::Accessor::Fast};
use Data::Dumper;

#===============================================================================
#    FILE:  ATOM.pm
#  AUTHOR:  Hiroyuki Nakamura <hiroyuki@sfc.keio.ac.jp>
# VERSION:  1.0
# CREATED:  2009/01/12 11時41分27秒 JST
#===============================================================================

# !!!! NOTICE !!!!
# Interface of Bio::PDB::ASA is diffrent from other Bio::(Entrys)
# new(filehandle)

__PACKAGE__->mk_accessors(qw{rows cursor});
sub new {
    my ($class, $annotation) = @_;

    unless ($annotation->isa("GLOB")) {
        croak "Argument of Bio::PDB::ATOM#new is GLOB";
    }

    my $this = bless {}, $class;
    my @rows;

    while (<$annotation>) {
        chomp;
        my $row = Bio::PDB::ASA::Row->new($_);
        push @rows, $row if $row;
    }

    $this->rows(\@rows);
    $this->cursor(0);
    return $this;
}

sub next {
    my $this = shift;
    my $rows = $this->rows;
    if ($#{$rows} != $this->cursor) {
        my $retrow = $rows->[$this->cursor];
        $this->cursor(($this->cursor + 1));
        return $retrow;
    }
    else {
        return undef;
    }
}

sub prev {
    my $this = shift;
   my $rows = $this->rows;
   if ($this->cursor != 1) {
       my $retrow = $rows->[$this->cursor];
       $this->cursor(($this->cursor - 1));
       return $retrow;
   }
   else {
       return undef; 
   }
}

package Bio::PDB::ASA::Row;

use strict;
use warnings;
use Carp qw{croak carp};
use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(qw{
  position residue chain asa indexnum
});

{
    my $index = 0;
    my $savedpos = 0;

    sub set_savedpos {
        my $pos = shift;
        if ( $pos ) {
            $savedpos = $pos; 
        }
        else {
            carp "No Argument - Bio::PDB::ASA::Row#savedpos";
        }
    }
    sub get_savedpos  { return $savedpos; }

    sub increment_index {
        $index++; 
    }
    sub get_index {
        return $index; 
    }
}

sub new {
    my ( $class, $line, $index ) = @_;
    my $this = bless {}, $class;
    if (/^ATOM\s+?(\d+?)\s+?(.+?)\s+?(\w{3})\s+?(\w+?)\s+?(\d+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)$/) {
        $this->position($5); 
        $this->residue($3); 
        $this->chain($4); 
        $this->asa($10); 
        $this->indexnum(get_index()); 
        if ( get_savedpos && get_savedpos != $5  ) {
            increment_index();
        }
        set_savedpos($5);
    }
    elsif (/^ATOM/) {
        carp qq{Cannot parse line : $_\n};
        return 0;
    }
    elsif (/^HETATM/) {
        carp qq{HETATM record is ignored\n};
        return 0;
    }

    return $this;
}

1;