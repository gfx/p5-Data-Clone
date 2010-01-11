#!perl -w

use strict;

use Benchmark qw(:all);

use Clone ();
use Data::Clone ();

print "Scalar:\n";
cmpthese -1 => {
    Clone => sub{
        my $x = Clone::clone("foobar");
    },
    'Data::Clone' => sub{
        my $x = Data::Clone::clone("foobar");
    },
};

my @array = (
    [1 .. 10],
    ["foo", "bar", "baz"]
);

print "Array:\n";
cmpthese -1 => {
    Clone => sub{
        my $x = Clone::clone(\@array);
    },
    'Data::Clone' => sub{
        my $x = Data::Clone::clone(\@array);
    },
};

my %hash = (
    key => \@array,
);
print "Hash:\n";
cmpthese -1 => {
    Clone => sub{
        my $x = Clone::clone(\%hash);
    },
    'Data::Clone' => sub{
        my $x = Data::Clone::clone(\%hash);
    },
};
