use inc::Module::Install;
name 'Bio-PDB';
all_from 'lib/Bio/PDB.pm';

requires 'bioperl';
requires 'Class::Accessor';
requires 'File::Util';
requires 'File::Path';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
