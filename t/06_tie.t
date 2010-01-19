#!perl -w

use strict;
use warnings FATAL => 'all';

use Test::More;

use Data::Clone;

use Tie::Hash;
use Tie::Array;

use Data::Dumper;
$Data::Dumper::Indent   = 0;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Useqq    = 1;

{
    package MyNonclonableHash;
    our @ISA = qw(Tie::StdHash);

    package MyNonclonableArray;
    our @ISA = qw(Tie::StdArray);

    package MyClonableHash;
    use Data::Clone qw(TIECLONE);
    our @ISA = qw(Tie::StdHash);

    package MyClonableArray;
    use Data::Clone qw(TIECLONE);
    our @ISA = qw(Tie::StdArray);
}

# HASH

foreach (1 .. 2){
    note "for HASH ($_)";
    tie my %h, 'MyNonclonableHash';
    $h{foo} = 42;
    $h{bar} = "xyzzy";

    my $c;
    eval{
        clone(\%h);
    };
    like $@, qr/Non-clonable object/, 'clone() croaks by default';

    eval{
        local $Data::Clone::ObjectCallback = sub{ $_[0] };
        $c = clone(\%h);
    };

    is tied(%{$c}), tied(%h), 'sutface copy';
    $c->{foo}++;
    is Dumper($c),  Dumper({ foo => 43, bar => "xyzzy" });
    is Dumper(\%h), Dumper({ foo => 43, bar => "xyzzy" });

    tie %h, 'MyClonableHash';
    $h{foo} = 42;
    $h{bar} = "xyzzy";

    $c = clone(\%h);

    isnt $c, \%h;
    $c->{foo}++;
    is Dumper($c),  Dumper({ foo => 43, bar => "xyzzy" });
    is Dumper(\%h), Dumper({ foo => 42, bar => "xyzzy" });

    # ARRAY
    note("for ARRAY ($_)");
    tie my @a, 'MyNonclonableArray';
    @a = (42, "xyzzy");

    eval{
        clone(\@a);
    };
    like $@, qr/Non-clonable object/, 'clone() croaks by default';

    eval{
        local $Data::Clone::ObjectCallback = sub{ $_[0] };
        $c = clone(\@a);
    };

    is tied(@{$c}), tied(@a), 'sutface copy';
    $c->[0]++;
    is Dumper($c),  Dumper([43, "xyzzy"]);
    is Dumper(\@a), Dumper([43, "xyzzy"]);

    tie @a, 'MyClonableArray';
    @a = (42, "xyzzy");

    $c = clone(\@a);

    $c->[0]++;
    is Dumper($c),  Dumper([43, "xyzzy"]);
    is Dumper(\@a), Dumper([42, "xyzzy"]);
}

done_testing;
