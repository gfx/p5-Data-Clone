package Data::Clone;

use 5.008_001;
use strict;

our $VERSION = '0.001';

use XSLoader;
XSLoader::load(__PACKAGE__, $VERSION);

use parent qw(Exporter);
our @EXPORT = qw(clone data_clone);

1;
__END__

=head1 NAME

Data::Clone - Extensible, flexible, high-performance data cloning

=head1 VERSION

This document describes Data::Clone version 0.001.

=head1 SYNOPSIS

    # as a function
    use Data::Clone;

    my $data   = YAML::Load("foo.yml");
    my $cloned = clone($data);

    # makes Foo clonable
    package Foo;
    use Data::Clone;
    # ...

    # Foo is clonable
    my $o = Foo->new();
    my $c = clone($o); # $o is deeply copied

    # used for custom clone methods
    package Bar;
    use Data::Clone qw(data_clone);
    sub clone {
        my($proto) = @_;
        my $object = data_clone($proto);
        $object->do_something();
        return $object;
    }
    # ...

    # Bar is also clonable
    $o = Bar->new();
    $c = clone($o); # Bar::clone() is called

=head1 DESCRIPTION

Data::Clone does data cloning, i.e. copies things recursively. This is
smart so that it works with not only non-blessed references, but also with
blessed references (i.e. objects). When C<clone()> finds an object, it
calls a C<clone> method of the object if the object has a C<clone>, otherwise
it makes a surface copy of the object.

=head2 Cloning policy

=head3 Scalar references

Scalar references are B<not> copied deeply. They are copied in surface
because it is typically used to refer to something special, namely
global variables or magical variables.

=head3 Array references

Array references are copied deeply.

=head3 Hash references

Hash references are copied deeply.

=head3 Glob, IO and Code references

These references are B<not> copied deeply. They are copied in surface.

=head3 Blessed references (objects)

Blessed references are B<not> copied deeply by default. They will be copied
deeply when Data::Clone knows they are clonable, i.e. they have a C<clone>
method.

If you want an object clonable, you can use the C<clone()> function as a method:

    package Your::Class;
    use Data::Clone;

    # ...

    my $c = clone($your_object); # $your_object->clone() will be called

Or you can import C<data_clone()> function to define your custom clone method:

    package Your::Class;
    use Data::Clone qw(data_clone);

    sub clone {
        my($proto) = @_;
        my $object = data_clone($proto);
        # anything what you want
        return $object;
    }

Of course, you can use C<Clone::clone()>, C<Storable::dclone()>, and/or
anything you want.

=head1 INTERFACE

=head2 Exported functions

=head3 B<< clone(Scalar) >>

=head2 Exportable functions

=head3 B<< data_clone(Salar) >>

The same as C<clone()>. Provided for custom clone methods.

=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<Clone>, C<Storable>

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Goro Fuji (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
