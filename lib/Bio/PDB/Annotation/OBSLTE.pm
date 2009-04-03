package Bio::PDB::Annotation::OBSLTE;

use strict;
use warnings;
use base qw{Class::Accessor::Fast};
use Carp qw{carp croak confess};
use Data::Dumper;

__PACKAGE__->mk_accessors(qw{rep_date idcode ridcodes});

sub new {
    my ($class, $annotations ) = @_;
    my $this = bless {}, $class;

    if ( $#{$annotations} >= 1 ) {
        # multiple line.
        my $tmp_hash = _first_line( +( shift @{$annotations} )->value );
        carp qq[Bio::PDB::Annotation::OBSLTE does not support multiline OBSLTE!];

        while ( my ($f, $v) = each %{$tmp_hash} ) {
            no strict 'refs';
            $this->$f($v);
        }

        # TODO : Multiline OBSLTE
        #
        # for my $string ( @{$annotations} ) {
        #     my $tmp_hash_multi = _multi_line($string);
        #     while ( my ($f, $v) = each %{$tmp_hash_multi} ) {
        #         if (ref $v eq 'ARRAY') {
        #             push @{$tmp_hash->{$f}}, @{$v};
        #         } 
        #         else {
        #            my $tmp_a = delete $tmp_hash->{$f};
        #            @{$tmp_hash->{$f}} = [@{$tmp_a}, @{$v}];
        #         }
        #     }
        # }
    }
    else {
        # single line. 
        my $string = $annotations->[0]->value;
        my $tmp_hash = _first_line($string);
        while ( my ($f, $v) = each %{$tmp_hash} ) {
            no strict 'refs';
            $this->$f($v);
        }
    }
    return $this;
}


sub _first_line {
    my $string = shift;
    my $str_length = length $string;
    my ( $tmp, @tmp_rids );
    my $tmp_hash;
    my $fields = {
        rep_date    => [ [0, 9] ],
        idcode      => [ [10 ,4] ],
        ridcode     => [ [20, 4],
        [29, 4],
        [35, 4],
        [41, 4],
        [47, 4],
        [53, 4],
        [59, 4],
        [65, 4], ]
    };

    while ( my( $field, $substrs) = each %{$fields} ) {
        for my $substr (@$substrs) {
            if ( ($substr->[0] + $substr->[1]) < $str_length ) {
                $tmp = substr $string, $substr->[0], $substr->[1];
                $tmp =~ tr/ //d;
                if ($field eq 'ridcode') {
                    push @tmp_rids, $tmp if $tmp;
                }
                else {
                    $tmp_hash->{$field} = $tmp;
                }
            }
            $tmp = '';
        }
    }

    $tmp_hash->{ridcodes} = \@tmp_rids;

    return $tmp_hash;
}

sub _multi_line {
    # TODO : Multiline OBSLTE
}

1;
