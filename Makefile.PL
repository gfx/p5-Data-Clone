use strict;
use warnings;
use inc::Module::Install;

all_from 'lib/Data/Clone.pm';

use_ppport 3.19;
cc_warnings;

requires_xs 'XS::Assert';

test_requires 'Test::More' => 0.88; # done_testing()

tests 't/*.t', 't/*/*.t';
author_tests 'xt';

auto_set_repository() if -d '.git';

clean_files qw(
    Data-Clone-* *.stackdump
    *.gcda *.gcno *.gcov
    nytprof *.out
    cover_db
);

WriteAll check_nmake => 0;

