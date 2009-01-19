#!/usr/bin/perl 
use strict;
use warnings;
use lib qw{../..//lib2/bio_pdb/lib};
use Bio::PDB::DB::File;
use Data::Dumper;
my $db = Bio::PDB::DB::File->new('pdb_dir' => '/home/t04632hn/db/pdb/',
	'cache_dir' => '/tmp/pdbcache'
);

my $obj = $db->get_as_object('1SVC');

my $asa = '/home/t04632hn/db/pdb_asa/sv/pdb1svc.ent';

$obj->attach_asa($asa);

print qq{Forward iterate\n};
while (my $row = $obj->asa->next) {
	print $row->chain." | ".$row->position." | ".$row->residue." | ".$row->atom." | ".$row->asa."\n";
}

# print qq{Reverse iterate\n};
# while (my $row = $obj->asa->prev) {
# 	print $row->position." | ".$row->residue." | ".$row->atom." | ".$row->asa."\n";
# }

print $obj->asa_score_around(6,338,'P')."\n";
print $obj->residue_at(338)."\n";

