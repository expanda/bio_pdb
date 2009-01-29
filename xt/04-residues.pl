#!/usr/bin/perl 
use strict;
use warnings;
use FindBin qw{$Bin};
use lib qq{$Bin/../lib};
use Bio::PDB::DB::File;
use Data::Dumper;

my $db = Bio::PDB::DB::File->new('pdb_dir' => '/home/t04632hn/db/pdb/',
	'cache_dir' => '/tmp/pdbcache'
);

my $obj = $db->get_as_object('1SVC');
#print Dumper $obj->residues();
print "$_\n" for $obj->find_residues_by_name("TYR", only_position => 1, exclude => [82, 90] );
#print Dumper $obj->residues();

