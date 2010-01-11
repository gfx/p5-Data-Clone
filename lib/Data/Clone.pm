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

    use Data::Clone;

    my $cloned = clone($data);

=head1 DESCRIPTION

Data::Clone provides blah blah blah.

=head1 INTERFACE

=head2 Class methods

=over 4

=item *

=back

=head2 Instance methods

=over 4

=item *

=back


=head1 DEPENDENCIES

Perl 5.8.1 or later, and a C compiler.

=head1 BUGS

No bugs have been reported.

Please report any bugs or feature requests to the author.

=head1 SEE ALSO

L<perl>

=head1 AUTHOR

Goro Fuji (gfx) E<lt>gfuji(at)cpan.orgE<gt>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, Goro Fuji (gfx). All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
