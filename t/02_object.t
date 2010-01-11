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
}

for(1 .. 2){ # do it twice to test TARG

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

    $o = MyCustomClonable->new(foo => MyClonable->new(bar => 42));
    $c = clone($o);

    $c->{foo}{bar}++;
    is $o->{foo}{bar}, 42, 'clone() is reentrant';
    is $c->{foo}{bar}, 43;
}

done_testing;
