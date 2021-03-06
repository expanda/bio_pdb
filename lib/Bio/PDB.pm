package Bio::PDB;

use strict;
use warnings;
use Bio::Structure::IO;
use Array::Utils qw(:all);
use Carp qw{croak confess carp};
use Data::Dumper;

use Error qw{:try};

use Bio::PDB::Annotation::DBREF;
use Bio::PDB::Annotation::SEQADV;
use Bio::PDB::Annotation::OBSLTE;
use Bio::PDB::Annotation::REMARK::465;
use Bio::PDB::ASA;
use Bio::PDB::Util;
use Bio::PDB::Util::ResTable;

our $VERSION = '0.0.1';

use base qw{Class::Accessor::Fast};

__PACKAGE__->mk_accessors(
    qw{id asa_file filename stream
    first_str sequence asa_stack
    obslte annotation_keys fast
    dbref seqadv remark_465 res_table});

# Subroutine Alias
CHECK {
    no strict 'refs';
    *{__PACKAGE__.'::obsolete'} = \&obslte;
    *{__PACKAGE__.'::asa'} = \&asa_stack;
}

sub new { #{{{
    my $class = shift;
    my $fname = shift;
    open my $fh, $fname or croak "new : $!";

    __PACKAGE__->new_from_filehandle($fh, @_);
} #}}}
sub new_from_filehandle {#{{{
    my $class = shift;
    my $filehandle = shift;

    my $args = {
        fast => 0, 
        @_
    };

    my $this = bless {} ,$class;
    $this->fast($args->{fast});
    try {
        $this->stream(Bio::Structure::IO->new( -fh => $filehandle , -format => 'PDB' ));
        $this->first_str($this->stream->next_structure()) 
    }
    catch Bio::Root::Exception with {
        my $err = shift;
        print "$err\n";
        return undef ;
    }

    my $annotation_keys ;

    for my $key ( $this->first_str->annotation->get_all_annotation_keys ) {
        $annotation_keys->{$key} = 1; 
    }

    $this->annotation_keys($annotation_keys);

    if ($this->has_annotation('obslte')) {
        $this->init_annotation('obslte');
    }

    if ($this->has_annotation('seqadv')) {
        $this->init_annotation('seqadv');
    }

    $this->res_table(Bio::PDB::Util::ResTable->new($this->seqadv));

    unless ( $this->fast ) {
        if ($this->has_annotation('dbref')) {
            $this->init_annotation('dbref');
        }
    }

    return $this;
}#}}}
sub replaced {#{{{
    my $this = shift;
    if ($this->obslte) {
        return $this->obslte->rid_codes;
    }
    else {
        return 0; 
    }
}
#}}}
sub init_annotation { #{{{
    my $this = shift;
    my $annotation_key = shift;
    my @supported_annotations = ('dbref', 'seqadv', 'obslte', 'remark_465');
    my @hit;
    if ( @hit = grep { $annotation_key eq $_ } @supported_annotations ) {
        my $class_name = uc shift @hit;
        $class_name =~ s/_/::/g;
        {
            no strict 'refs';
            unless ( $this->$annotation_key() ) {
                $this->$annotation_key("Bio::PDB::Annotation::$class_name"->new([$this->first_str->annotation->get_Annotations($annotation_key)]));
            } 
        }
    }
}
#}}}
sub has_annotation {#{{{
    my $this = shift;
    my $annotation_key = $this->annotation_keys;
    return defined $annotation_key->{+( shift )};
}
#}}}
############ Utility methods
sub dbseq {#{{{ exclude SEQADV from SEQRES
    my $this = shift;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    my $base_seq = $this->first_str->seqres($chain)->seq();
    return $base_seq unless $this->seqadv;
    my $before_base = $this->seqadv->insert_before($chain);
    my $result_seq = $base_seq;

    if ( $before_base ) {
        $result_seq =~ s/$before_base//;
    }

    return $result_seq;
}
#}}}
sub chains {#{{{
    my $this = shift;
    return $this->first_str->get_chains();
}
#}}}
sub residues { #{{{
    my $this = shift;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    my $chainobj;
    for my $c ($this->first_str->get_chains()) {
        $chainobj = $c and last if ($c->{id} eq $chain);
    }
    confess "Cannot find chain." unless $chainobj;
    return $this->first_str->get_residues($chainobj);
}
#}}}
sub residues_to_s {#{{{
    my $this = shift;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    my $opts = {
        ignore => [],
        @_
    };
    my $str;
    for my $res ( $this->residues($chain) ) {
        if ( $res->id =~ /^([A-Z]+?)-(\d+?)$/ ) {
            my $letter = $this->res_table->to_1($1);
            $str .= $letter if $letter;
        }
    }
    return $str;
}#}}}
sub find_residues_by_name { #{{{ find_residues_by_name(name, chain => A, only_position => 1, exclude => [118, 119, 210])
    my $this = shift;
    my $name = shift || carp "Usage : find_residues_by_name(name, {chain => A, only_position => 0})";
    my $opt = {
        chain => (shift @{[$this->first_str->get_chains()]})->id,
        only_position => 0,
        exclude => [],
        @_
    };

    my @grepped = grep { $_->id =~ /^$name-\d+/ } $this->residues($opt->{chain});

    if (scalar @{$opt->{exclude}} > 0) {
        my $position_hash = {};
        $position_hash->{$_} = 1 for @{$opt->{exclude}};
        @grepped = 	grep {
            $_->id =~ /^.+?-(\d+)/;
            $_ if ( !(defined $position_hash->{$1}) );
        } @grepped;
    }

    if ( $opt->{only_position} ) {
        return map { if ($_->id =~ /^$name-(\d+)$/){ $1; } } @grepped;
    }
    else {
        return @grepped;	
    }
}
#}}}
sub residue_at { #{{{  $this->residue_at(10, 'A');
    my $this = shift;
    my $pos = shift;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    #print $pos;
    my $chainobj;
    for my $c ($this->first_str->get_chains()) {
        $chainobj = $c and last if ($c->{id} eq $chain);
    }

    if ($chainobj) {
        for my $res ( $this->first_str->get_residues($chainobj) ) {
            if ( $res->id =~ /^([A-Z]+?)-(\S+?)$/ ) {
                return $1 if ($2 == $pos);
            }
        }
    }
    else {
        carp "Not Found Chain $chain\n";
    }
}#}}}
sub residue_start_from { #{{{ # position from start (not seqid.)
    my $this = shift;
    my $pos = shift;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    #print $pos;
    my $chainobj;
    for my $c ($this->first_str->get_chains()) {
        $chainobj = $c and last if ($c->{id} eq $chain);
    }
    my $cpos = 1;
    if ($chainobj) {
        for my $res ( $this->first_str->get_residues($chainobj) ) {
            if ( $res->id =~ /^([A-Z]+?)-(\S+?)$/ ) {
                return ( $1, $2 ) if ($cpos == $pos);
                $cpos++;
            }
        }
    }
    else {
        carp "Not Found Chain $chain\n";
    }
}#}}}
sub start_res_num_of {#{{{
    carp "[TODO] start_res_num_of has not been implemented\n";
}
#}}}
############ ASA handling methods
sub attach_asa { #{{{
    my $this = shift;
    my $filename = shift;
    $this->asa_file($filename);
    if ( -f $filename ) {
        $this->read_asa_score;
    }
    else {
        carp "attach_asa : $filename file not found." 
    }
}
#}}}
sub read_asa_score { #{{{
    my $this = shift;
    my $asa_stack = [];
    open my $infh,  File::Spec->rel2abs($this->asa_file) || croak "ASA File cannnot open.";
    $this->asa_stack(Bio::PDB::ASA->new($infh));
}
#}}}
sub asa_stack_min_index {#{{{
    my $this = shift;
    my $min = shift @{$this->asa_stack->rows};
    unshift @{$this->asa_stack->rows}, $min;
    return $min->indexnum;
}#}}}
sub asa_stack_min_position {#{{{
    my $this = shift;
    my $min = shift @{$this->asa_stack->rows};
    unshift @{$this->asa_stack->rows}, $min;
    return $min->position;
}#}}}
sub asa_stack_max_index {#{{{
    my $this = shift;
    my $max = pop @{$this->asa_stack->rows};
    push @{$this->asa_stack->rows}, $max;
    return $max->indexnum;
}#}}}
sub asa_stack_max_position {#{{{
    my $this = shift;
    my $max = pop @{$this->asa_stack->rows};
    push @{$this->asa_stack->rows}, $max;
    return $max->position;
}#}}}
sub asa_score_around {#{{{
    my $this = shift;
    my ($range, $midium, $chain ) = @_;
    carp "[Bio::PDB#asa_score_around] Less argument: midium is required." unless defined $midium;
    $chain ||= (shift @{[$this->first_str->get_chains()]})->id;
    my $start = $midium - ($range/2);
    my $end = $midium + ($range/2);
    my $total_asa;
    $this->read_asa_score unless $this->asa_stack;

    for my $row ( @{$this->asa_stack->rows} ) {
        $total_asa += $row->asa
        if ( $start <= $row->position && $row->position <= $end && $row->chain eq $chain );
    }

    return $total_asa;
}
#}}}
sub asa_score_around_n_of_random_selected { #{{{ default around 6.
    my $this = shift;
    my $residue = shift;
    my $around = shift || 6;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    my $total_asa = 0;
    $this->read_asa_score unless $this->asa_stack;

    my $max_index = $this->asa_stack_max_index;
    my @stack_of_res = grep { $_->chain eq $chain && $_->residue eq $residue } @{$this->asa_stack->rows};

    carp "No $residue Found." and return if scalar @stack_of_res == 0;

    my $chk = 0;
    my $random_selected;
    while ( $random_selected = delete $stack_of_res[int(rand($#stack_of_res))] ) {

        unless ( ( $random_selected->indexnum <= ($around/2) )
            && ($random_selected->indexnum + ($around/2) ) >= $max_index ) {
            $chk = 1;
            last;
        }
        else {
            $random_selected = undef;
        }

    }

    return if $chk == 0;

    my ($start, $end) = (( $random_selected->{position} - ($around/2)), ($random_selected->{position} + 3));
    my ($starti, $endi) = (( $random_selected->{indexnum} - ($around/2)), ($random_selected->{indexnum} + 3));

    #print "$starti $endi OKOKOK\n";
    my $tmpr;
    for my $atom (@{$this->asa_stack->rows}) {
        if ( $atom->{position} >= $start && $atom->{position} <= $end && $atom->{chain} eq $chain ) {
            $total_asa += $atom->{asa};
            unless ( $tmpr ) { $tmpr = $atom->{residue}; } #print $tmpr."\n"; }
            if ( $tmpr ne $atom->{residue}) {
                #print $atom->{residue}."\n";
                $tmpr = $atom->{residue};
            }
        }
        elsif ( $atom->{position} > $end ) {
            last;
        }
    }

    return $total_asa;
}
#}}}
sub asa_score_around_n_of_random {#{{{ 09/01/29 : do not use. I have not check this method yet.
    my $this = shift;
    my $opt = {
        exclude => [],
        around => 6,
        residue => '',
        chain => (shift @{[$this->first_str->get_chains()]})->id,
        @_
    };
    my $total_asa = 0;
    $this->read_asa_score unless $this->asa_stack;

    my $max_index = $this->asa_stack_max_index;	
    my @stack_of_res = $this->find_residues_by_name($opt->{residue}, {
            'chain' => $opt->chain,
        });
    my $position_hash = {};
    $position_hash->{$_} = 1 for @{$opt->{exclude}};
    @stack_of_res = grep { !(defined $position_hash->{$_->position}) } @stack_of_res;

    my $target = delete $stack_of_res[int(rand($#stack_of_res))];

    return $this->asa_score_around( $opt->{around}, $target->position, $opt->{chain} );
}#}}}
sub asa_score_around_n_of_random_other_than { #{{{ asa_score_around_n_of_random_other_than(exclude_position, residue, around, chain)
    my $this = shift;
    my $exclude = shift;
    my $residue = shift;
    my $around = shift || 6;
    my $chain = shift || (shift @{[$this->first_str->get_chains()]})->id;
    my $total_asa = 0;
    $this->read_asa_score unless $this->asa_stack;

    my $max_index = $this->asa_stack_max_index;
    my @stack_of_res = grep {
        $_->chain eq $chain &&
        $_->residue eq $residue &&
        $_->position != $exclude } @{$this->asa_stack->rows};

    carp "No $residue Found." and return if scalar @stack_of_res == 0;

    my $chk = 0;
    my $random_selected;
    while ( $random_selected = delete $stack_of_res[int(rand($#stack_of_res))] ) {

        unless ( ( $random_selected->indexnum <= ($around/2) )
            && ($random_selected->indexnum + ($around/2) ) >= $max_index ) {
            $chk = 1;
            last;
        }
        else {
            $random_selected = undef;
        }

    }

    return if $chk == 0;

    my ($start, $end) = (( $random_selected->{position} - ($around/2)), ($random_selected->{position} + 3));
    my ($starti, $endi) = (( $random_selected->{indexnum} - ($around/2)), ($random_selected->{indexnum} + 3));

    #print "$starti $endi OKOKOK\n";
    my $tmpr;
    for my $atom (@{$this->asa_stack->rows}) {
        if ( $atom->{position} >= $start && $atom->{position} <= $end && $atom->{chain} eq $chain ) {
            $total_asa += $atom->{asa};
            unless ( $tmpr ) { $tmpr = $atom->{residue}; } #print $tmpr."\n"; }
            if ( $tmpr ne $atom->{residue}) {
                #print $atom->{residue}."\n";
                $tmpr = $atom->{residue};
            }
        }
        elsif ( $atom->{position} > $end ) {
            last;
        }
    }

    return $total_asa;
}
#}}}
sub asa_score_at { #{{{
    my $this = shift;
    my $position = shift;
    my $chain = shift || "A";
    my ($total_asa);
    for my $atom (@{$this->asa_stack->rows}) {
        if ($atom->position == $position
                and $atom->chain eq $chain) {
            last if ( $position && $position != $atom->position);
            $total_asa += $atom->asa;
        }
    }
    return $total_asa;
}
#}}}
1;
__END__

