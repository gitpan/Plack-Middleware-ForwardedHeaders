use strict;
use warnings;

use Test::More tests => 1;

for my $module (qw(
    Plack::Middleware::ForwardedHeaders
)) {
    require_ok( $module )
        || BAIL_OUT( "Can't continue if module can't compile" );
}

