package Bio::PDB::Annotation::REMARK::465;

use strict;
use warnings;
use Data::Dumper;
use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(
    qw{rows}
);

sub new {
    my ($class, $annotations) = @_;
	 return unless $annotations;
	 my $string = $annotations->[0]->value;
	 my $this = bless {}, $class;
	 print Dumper $annotations->[0]->hash_tree();
	 my $i=0;
	 my @rows;

	 while (my $l = substr $string, $i, 59) {
		 if ($l =~ /[A-Z]*\s+?[A-Z]{3}\s+?[A-Z]{1}\s+?\d+?\s+?\d*/) {
			 push @rows, Bio::PDB::Annotation::REMARK::465::Row->new($l);
		 }
		 $i += 59;
    }

	 $this->rows(\@rows);

    return $this;
 }

package Bio::PDB::Annotation::REMARK::465::Row;

use strict;
use warnings;
use base 
qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(
    qw{model chain_id res_name seq_num i_code}
);

sub new {
    my ($class, $string) = @_;
    my $this = bless {}, $class;
    my $tmp;
    my $fields = {
        model        => [2, 1],
        res_name     => [4, 3],
        chain_id     => [8, 1],
        seq_num      => [11, 4],
        i_code       => [15, 1],
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
