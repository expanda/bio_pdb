use inc::Module::Install;
name 'Bio-PDB';
all_from 'lib/Bio/PDB.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
