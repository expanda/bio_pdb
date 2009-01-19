#!/usr/bin/perl 
use strict;
use warnings;
use lib qw{../..//lib2/bio_pdb/lib};
use Bio::PDB::DB::File;
use Data::Dumper;
my $db = Bio::PDB::DB::File->new('pdb_dir' => '/home/t04632hn/db/pdb/',
	'cache_dir' => '/tmp/pdbcache'
);

#my $fh = $db->get_as_filehandle('2QYP');
my $obj = $db->get_as_object('1WMA');

print $obj->residue_at(192, 'A')."\n";
print $obj->residue_at(193, 'A')."\n";
print $obj->residue_at(194, 'A')."\n";
print $obj->residue_at(195, 'A')."\n";
print $obj->residue_at(196, 'A')."\n";
#while (<$fh>) {
#    print $_;
#}

#print Dumper $obj;

#$db->clear_cache;
