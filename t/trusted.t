use strict;
use warnings;

use Test::More tests => 3;

use Plack::Test;
use Plack::Middleware::ForwardedHeaders;
use HTTP::Request;

my $client = sub {
    my $cb = shift;
    my $req = HTTP::Request->new(GET => 'http://localhost/');
    $req->header('X-Forwarded-For' => '200.200.200.200');
    $cb->($req);
};

test_psgi
    app => Plack::Middleware::ForwardedHeaders->wrap(
        sub {
            my $env = shift;
            is $env->{REMOTE_ADDR}, '127.0.0.1', 'Headers not used for untrusted proxies';
            return [200, ['Content-Type' => 'text/plain'], ['']];
        },
        trusted => '100.100.100.100',
    ),
    client => $client,
;

test_psgi
    app => Plack::Middleware::ForwardedHeaders->wrap(
        sub {
            my $env = shift;
            is $env->{REMOTE_ADDR}, '200.200.200.200', 'Headers used for trusted proxies';
            return [200, ['Content-Type' => 'text/plain'], ['']];
        },
        trusted => '127.0.0.1',
    ),
    client => $client,
;

test_psgi
    app => Plack::Middleware::ForwardedHeaders->wrap(
        sub {
            my $env = shift;
            is $env->{REMOTE_ADDR}, '200.200.200.200', 'Array reference allowed for trusted';
            return [200, ['Content-Type' => 'text/plain'], ['']];
        },
        trusted => [ '1.1.1.1', '127.0.0.1' ],
    ),
    client => $client,
;
