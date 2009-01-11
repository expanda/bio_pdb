use inc::Module::Install;
name 'Bio-PDB';
all_from 'lib/Bio/PDB.pm';

requires 'Bio::Structure::IO';
requires 'Class::Accessor';
requires 'IO::Uncompress::Gunzip';
requires 'File::Util';
requires 'File::Find';
requires 'File::Spec';
requires 'File::Path';
requires 'Array::Utils';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
