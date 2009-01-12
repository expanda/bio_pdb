#!/usr/bin/perl 
use strict;
use warnings;
use lib qw{../lib};
use Bio::PDB::DB::File;
use Data::Dumper;
my $db = Bio::PDB::DB::File->new('pdb_dir' => '/db/pdb/');

my $fh = $db->get_as_filehandle('2QYP');
my $obj = $db->get_as_object('2QYP');

while (<$fh>) {
    print $_;
}

print Dumper $obj;

$db->clear_cache;
