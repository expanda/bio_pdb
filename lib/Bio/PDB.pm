package Bio::PDB;
use strict;
use warnings;
use Data::Dumper;
use Bio::Structure::IO;
use Array::Utils qw(:all);
use Carp qw{croak confess carp};

our $VERSION = '0.0.1';

use base qw{Class::Accessor::Fast};
__PACKAGE__->mk_accessors(qw{archive tmp_dir id asa_dir asa filename stream first_str dbref seqadv sequence obsolete_dir dir asa_stack});

use Bio::PDB::DBREF;
use Bio::PDB::SEQADV;

sub new {
    my ($class, $id, $fast ) = @_;
    my $this = bless {} ,$class;

    $id = lc $id;

    $this->tmp_dir('/state/partition1/') unless $this->tmp_dir;
    $this->obsolete_dir('/home/t04632hn/db/pdb-obsolete/') unless $this->obsolete_dir;

    $this->_initialize($id);

    my $tmp = $this->tmp_dir;
    my $tmp_file = $this->tmp_dir.$this->filename;
    my $tmp_archive = $this->tmp_dir.$this->filename.".gz";

    unless (-e $tmp_file) {
        if (-e $this->archive ) {
            my $archive = $this->archive;
            qx/cp $archive $tmp/;
            qx/gzip -d $tmp_archive/;
        }
        else {
            # IF Obsolete ...
            my $obsolete = $this->obsolete_dir.$this->dir."/pdb$id.ent.gz";
            my $current;
            qx/cp $obsolete $tmp/;
            qx/gzip -d $tmp_archive/;
            my $tmpstream = Bio::Structure::IO->new( -file => $tmp_file, -format => 'PDB' );
            my @obs = $tmpstream->next_structure->annotation->get_Annotations('obslte');
            print $obs[0]->as_text."\n";
            if ( $obs[0]->as_text =~ /^Value:.+\s([A-Z0-9]{4})/ ) {
                $current = lc $1;
                $this->_initialize($current);
                $tmp_file = $this->tmp_dir.$this->filename.".gz";
                my $archive = $this->archive;
                qx/cp $archive $tmp/;
                qx/gzip -d $tmp_file/;		
            }
            else {
                croak "OBSOLETE. but cannot retrieve new file."	;
            }
        }
    }

    $this->stream(Bio::Structure::IO->new( -file => $tmp_file, -format => 'PDB' ));
    $this->first_str($this->stream->next_structure());

    if ($this->first_str->annotation()->get_Annotations('dbref') && !$fast ) {
        $this->dbref(PDB::DBREF->new($this->first_str->annotation()->get_Annotations('dbref')));
    }

    if ($this->first_str->annotation()->get_Annotations('seqadv') && !$fast ) {
        $this->seqadv(PDB::SEQADV->new($this->first_str->annotation()->get_Annotations('seqadv')));
    }

    return $this;
}

sub _initialize {
    my ($this, $id) = @_;
    my $dir;
    $this->id($id);
    if ( $id =~ m/^\w(\w{2})\w$/ ) {
        $dir = $1;
    }
    $this->dir($dir);
    $this->filename("pdb$id.ent");
    $this->archive(qq{/home/t04632hn/db/pdb/$dir/pdb$id.ent.gz});
    #$this->asa(qq{/home/t04632hn/db/pdb_asa_3a/$dir/pdb$id.ent});
    $this->asa(qq{/home/t04632hn/db/pdb_asa/$dir/pdb$id.ent});
}

# exclude ADVSEQ
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
