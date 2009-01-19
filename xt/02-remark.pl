#!/usr/bin/perl 
use strict;
use warnings;
use lib qw{../..//lib2/bio_pdb/lib};
use Bio::PDB::DB::File;
use Data::Dumper;
my $db = Bio::PDB::DB::File->new('pdb_dir' => '/home/t04632hn/db/pdb/',
	'cache_dir' => '/tmp/pdbcache'
);

# with remark 465
my $obj = $db->get_as_object('1wma');

$obj->init_annotation('remark_465');

print $obj->position_unp_to_pdb(2)."\n";

print $obj->residue_at($obj->position_unp_to_pdb(194));
