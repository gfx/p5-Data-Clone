#!perl -w

use strict;
use warnings FATAL => 'all';

use Test::More;
use Data::Dumper;

use Data::Clone;

use Tie::Hash;
use Tie::Array;

$Data::Dumper::Indent = 0;

ok defined(&clone), 'clone() is exported by default';
ok!defined(&data_clone), 'data_clone() is not exported by default';

for(1 .. 2){ # do it twice to test internal data

    foreach my $data(
        "foo",
        3.14,
        1 != 1,
        *STDOUT,
        ["foo", "bar", undef, 42],
        [qr/foo/, qr/bar/],
        [\*STDOUT, \*STDOUT],
        { key => [ 'value', \&ok ] },
        { foo => { bar => { baz => 42 } } },
        bless({foo => "bar"}, 'Foo'),

        do{
            my $o = tie my(%h), 'Tie::StdHash';
            %{$o} = (foo => 'bar');
            \%h;
        },
        do{
            my $o = tie my(@a), 'Tie::StdArray';
            @{$o} = ('foo', 42);
            \@a;
        },
    ){
        is Dumper(clone($data)),  Dumper($data),  'data';
        is Dumper(clone(\$data)), Dumper(\$data), 'data ref';
    }


    my $s;
    $s = \$s;
    is Dumper(clone(\$s)), Dumper(\$s), 'ref to self (scalar)';

    my @a;
    @a = \@a;
    is Dumper(clone(\@a)), Dumper(\@a), 'ref to self (array)';

    my %h;
    $h{foo} = \%h;
    is Dumper(clone(\%h)), Dumper(\%h), 'ref to self (hash)';

    @a = ('foo', 'bar', \%h, \%h);
    is Dumper(clone(\@a)), Dumper(\@a), 'ref to duplicated refs';

    # correctly cloned?

    %h = (foo => 10);

    my $cloned = clone(\%h);
    $cloned->{foo}++;

    cmp_ok $cloned, '!=', \%h, 'different entity';
    is_deeply \%h,     {foo => 10}, 'deeply cloned';
    is_deeply $cloned, {foo => 11};
}

done_testing;
