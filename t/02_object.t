#!perl -w

use strict;
use warnings FATAL => 'all';

use Test::More;

use Data::Clone;

{
    package MyBase;

    sub new {
        my $class = shift;
        return bless {@_}, $class;
    }

    package MyNoclonable;
    our @ISA = qw(MyBase);

    package MyClonable;
    use Data::Clone;
    our @ISA = qw(MyBase);

    package MyCustomClonable;
    use Data::Clone qw(data_clone);
    our @ISA = qw(MyBase);

    sub clone {
        my $cloned = data_clone(@_);
        $cloned->{bar} = 42;
        return $cloned;
    }

    package FatalClonable;
    our @ISA = qw(MyBase);

    sub clone {
        die 'FATAL';
    }
}

for(1 .. 2){ # do it twice to test internal data

    my $o = MyNoclonable->new(foo => 10);
    my $c = clone($o);

    is $c, $o, "($_)";
    $c->{foo}++;
    is $o->{foo}, 11, 'noclonable';

    $o = MyClonable->new(foo => 10);
    $c = clone($o);
    isnt $c, $o;
    $c->{foo}++;
    is $o->{foo}, 10, 'clonable';

    $o = MyCustomClonable->new(foo => 10);
    $c = clone($o);
    isnt $c, $o;
    $c->{foo}++;
    is $o->{foo}, 10, 'clonable';
    is_deeply $c, { foo => 11, bar => 42 }, 'custom clone()';

    $o = MyClonable->new(
        aaa => MyCustomClonable->new(value => 100),
        bbb => MyCustomClonable->new(value => 200),
    );
    $c = clone($o);

    $c->{aaa}{value}++;
    $c->{bbb}{value}++;

    is $o->{aaa}{value}, 100, 'clone() is reentrant';
    is $c->{aaa}{value}, 101;
    is $c->{aaa}{bar},    42;

    is $o->{bbb}{value}, 200, 'clone() is reentrant';
    is $c->{bbb}{value}, 201;
    is $c->{bbb}{bar},    42;

    $o = MyCustomClonable->new();
    $o->{ccc} = MyCustomClonable->new(value => 300);
    $o->{ddd} = $o->{ccc};

    $c = clone($o);
    $c->{ccc}{value}++;
    $c->{ddd}{value}++;

    is $o->{ccc}{value}, 300;
    is $c->{ccc}{value}, 302;
    is $c->{ccc}{bar},   42;

    $o = FatalClonable->new(foo => 10);
    eval{
        clone($o);
    };
    like $@, qr/^FATAL \b/xms, 'FATAL in clone()';
    is $o->{foo}, 10;

    $o = MyCustomClonable->new(value => FatalClonable->new(foo => 10));
    eval{
        clone($o);
    };
    like $@, qr/^FATAL \b/xms, 'FATAL in clone()';
    is $o->{value}{foo}, 10;
}

done_testing;
