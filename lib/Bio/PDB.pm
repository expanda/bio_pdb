package Bio::PDB;

use strict;
use warnings;
use Bio::Structure::IO;
use Array::Utils qw(:all);
use Carp qw{croak confess carp};
use Data::Dumper;

use Bio::PDB::DBREF;
use Bio::PDB::SEQADV;
use Bio::PDB::OBSLTE;

our $VERSION = '0.0.1';

use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(qw{id asa_dir asa filename stream first_str dbref seqadv sequence asa_stack obslte annotation_keys fast});

CHECK {
    no strict 'refs';
   *{__PACKAGE__.'::obsolete'} = \&obslte;
}

sub new {
    my $class = shift;
    my $fname = shift;
    open my $fh, $fname or croak "new : $!";

    __PACKAGE__->new_from_filehandle($fh, @_);
}

sub new_from_filehandle {
    my $class = shift;
    my $filehandle = shift;
    # obsolete check.
    my $args = {
        fast => 0, 
        @_
    };

    my $this = bless {} ,$class;
    $this->fast($args->{fast});
    $this->stream(Bio::Structure::IO->new( -fh => $filehandle , -format => 'PDB' ));
    $this->first_str($this->stream->next_structure());

    my $annotation_keys ;

    for my $key ( $this->first_str->annotation->get_all_annotation_keys ) {
        $annotation_keys->{$key} = 1; 
    }

    $this->annotation_keys($annotation_keys);

    if ($this->has_annotation('obslte')) {
        $this->init_annotation('obslte');
    } 

    unless ( $this->fast ) {
        if ($this->has_annotation('dbref')) {
            $this->init_annotation('dbref');
        }

        if ($this->has_annotation('seqadv')) {
            $this->init_annotation('seqadv');
        }
    }

    return $this;
}

sub replaced {
    my $this = shift;
    if ($this->obslte) {
        return $this->obslte->rid_codes;
    }
    else {
        return 0; 
    }
}

sub init_annotation {
    my $this = shift;
    my $annotation_key = shift;
    my @supported_annotations = ('dbref', 'seqadv', 'obslte');
    my @hit;
    if ( @hit = grep { $annotation_key eq $_ } @supported_annotations ) {
        my $class_name = uc shift @hit;
        {
            no strict 'refs';
            unless ( $this->$annotation_key() ) {
                $this->$annotation_key("Bio::PDB::$class_name"->new([$this->first_str->annotation->get_Annotations($annotation_key)]));
            } 
        }
    }
}

sub has_annotation {
    my $this = shift;
    my $annotation_key = $this->annotation_keys;
    return defined $annotation_key->{+( shift )};
}

# exclude SEQADV from SEQRES
sub dbseq {
    my $this = shift;
    my $chain = shift || "A";
    my $base_seq = $this->first_str->seqres($chain)->seq();
    return $base_seq unless $this->seqadv;
    my $before_base = $this->seqadv->insert_before($chain);
    my $result_seq = $base_seq;

    if ( $before_base ) {
        $result_seq =~ s/$before_base//;
    }

    return $result_seq;
}

sub start_res_num_of {
    carp "[TODO] start_res_num_of has not been implemented\n";
}

sub asa_score_around {
    my $this = shift;
    my ($range, $midium, $chain ) = @_;
    my $start = $midium - ($range/2);
    my $end = $midium + ($range/2);
    my $total_asa;

    open my $infh,  File::Spec->rel2abs($this->asa) || croak "ASA File cannnot open.";
    while (<$infh>) {
        chomp;  
        if (/^ATOM\s+?(\d+?)\s+?(.+?)\s+?(\w{3})\s+?(\w+?)\s+?(\d+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)$/) {
            my $tmp_res = $3;
            if ( $start <= $5 && $5 <= $end && $4 eq $chain) {
                $total_asa += $10;
            }
        }
    }
    close $infh;
    return $total_asa;
}

sub read_asa_score {
    my $this = shift;
    my $asa_stack = [];
    open my $infh,  File::Spec->rel2abs($this->asa) || croak "ASA File cannnot open.";
    my $index = 0;
    my $tmp_pos;
    while (<$infh>) {
        chomp;  
        if (/^ATOM\s+?(\d+?)\s+?(.+?)\s+?(\w{3})\s+?(\w+?)\s+?(\d+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)$/) {
            push @{$asa_stack}, { position => $5, residue => $3, chain => $4 , asa => $10, index => $index};
            $tmp_pos = $5 unless defined $tmp_pos;
            if ( $tmp_pos != $5  ) {
                $index++;
            }
            $tmp_pos = $5;
        }
    }
    close $infh;
    $this->asa_stack($asa_stack);
}

sub asa_stack_max_index {
    my $this = shift;
    my $max = pop @{$this->asa_stack};
    return $max->{index};
}

sub asa_score_around_6_of_random_selected {
    my $this = shift;
    my $residue = shift;
    my $chain = shift || 'A';
    my $total_asa = 0;
    $this->read_asa_score unless $this->asa_stack;

    my $max_index = $this->asa_stack_max_index;
    my @stack_of_res = grep { $_->{chain} eq $chain && $_->{residue} eq $residue } @{$this->asa_stack};
    #my @candidate_res_position = map { $_->{position} } @stack_of_res;
    #@candidate_res_position = unique(@caondidate_res_position);

    return if scalar @stack_of_res == 0;

    my $chk = 0;
    my $random_selected;
    while ( $random_selected = delete $stack_of_res[int(rand($#stack_of_res))] ) {
        unless ( $random_selected->{index} <= 3 && ($random_selected->{index} + 3) >= $max_index ) {
            $chk = 1;
            last;
        }
        else {
            $random_selected = undef;	
        }
    }

    return if $chk == 0;

    my ($start, $end) = (( $random_selected->{position} - 3 ), ($random_selected->{position} + 3));
    my ($starti, $endi) = (( $random_selected->{index} - 3 ), ($random_selected->{index} + 3));

    print "$starti $endi OKOKOK\n";
    my $tmpr;
    for my $atom (@{$this->asa_stack}) {
        if ( $atom->{position} >= $start && $atom->{position} <= $end && $atom->{chain} eq $chain ) {
            $total_asa += $atom->{asa};
            unless ( $tmpr ) { $tmpr = $atom->{residue}; print $tmpr."\n"; }
            if ( $tmpr ne $atom->{residue}) {
                print $atom->{residue}."\n";
                $tmpr = $atom->{residue};
            }
        }
        elsif ( $atom->{position} > $end ) {
            last;	
        }
    }

    print "ASA: $total_asa\n";
    return $total_asa;
}

sub asa_score_of_random_selected {
    my $this = shift;
    my $residue = shift;
    my $chain = shift || 'A';
    open my $infh,  File::Spec->rel2abs($this->asa) || croak "ASA File cannnot open.";
    my ( $total_asa, $position);
    while (<$infh>) {
        chomp; 
        #ATOM      1  N   MET A   0      24.452   8.196  -9.773  1.00 21.07
        if (/^ATOM\s+?(\d+?)\s+?(.+?)\s+?(\w{3})\s+?(\w+?)\s+?(\d+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)$/) {
            if ( $3 eq $residue && $4 eq $chain) {
                last if ( $position && $position != $5);
                $position = $5;
                $total_asa += $10;
                print $3."\t".$5."\t".$10."\n";
            }
        }
    }
    close $infh;
    return $total_asa;
}

sub asa_score_at {
    my $this = shift;
    my $position = shift;
    my $chain = shift || "A";
    my ($total_asa, $res);
    open my $infh,  File::Spec->rel2abs($this->asa) || croak "ASA File cannnot open.";
    while (<$infh>) {
        chomp;
        #ATOM      1  N   MET A   0      24.452   8.196  -9.773  1.00 21.07
        if (/^ATOM\s+?(\d+?)\s+?(.+?)\s+?(\w{3})\s+?(\w+?)\s+?(\d+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)\s+?([0-9.-]+?)$/) {
            #print $3."\t".$5."\t".$10."\n" if $5 == $position && $4 eq $chain;
            my $tmp_res = $3;
            if ( $5 == $position && $4 eq $chain) {
                $total_asa += $10;
                $res = $tmp_res;
                #print $res."\n";
            }
        }
    }
    close $infh;
    return ( $res, $total_asa);
}

1;
