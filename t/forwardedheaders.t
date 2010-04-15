use strict;
use warnings;

use Test::More tests => 12;

use Plack::Test;
use Plack::Middleware::ForwardedHeaders;
use HTTP::Request;
use Storable;

my $app = sub {
    my $env = shift;
    my $output = Storable::freeze({
        map { $_ => $env->{$_} } qw(
            psgi.url_scheme
            REMOTE_ADDR
            HTTP_HOST
        )
    });

    return [200, ['Content-Type' => 'text/plain'], [ $output ] ];
};
$app = Plack::Middleware::ForwardedHeaders->wrap($app, use_host => 1);

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        $req->header('X-Forwarded-Host', 'www.example.com');
        my $res = $cb->($req);
        my $env = Storable::thaw($res->content);
        is $env->{HTTP_HOST}, 'www.example.com', 'X-Forwarded-Host can set HTTP_HOST';
    },
;

for my $header (qw(
    X-Forwarded-For
    X-Real-IP
)) {
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            $req->header($header, '200.200.200.200');
            my $res = $cb->($req);
            my $env = Storable::thaw($res->content);
            is $env->{REMOTE_ADDR}, '200.200.200.200', $header . ' header sets remote address';
        },
    ;
}

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        $req->header('X-Forwarded-For', '100.100.100.100, 200.200.200.200');
        my $res = $cb->($req);
        my $env = Storable::thaw($res->content);
        is $env->{REMOTE_ADDR}, '200.200.200.200', 'X-Forwarded-For uses last of comma separated items';
    },
;

for my $header (
    ['X-Forwarded-Proto' => 'https'],
    ['X-Forwarded-Scheme' => 'https'],
    ['X-Forwarded-SSL' => 'on'],
    ['Front-End-HTTPS' => 'on'],
) {
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            $req->header(@$header);
            my $res = $cb->($req);
            my $env = Storable::thaw($res->content);
            is $env->{'psgi.url_scheme'}, 'https', $header->[0] . ' header can enable HTTPS';
        },
    ;
}

for my $header (
    ['X-Forwarded-Proto' => 'http'],
    ['X-Forwarded-Scheme' => 'http'],
    ['X-Forwarded-SSL' => 'off'],
    ['Front-End-HTTPS' => 'off'],
) {
    test_psgi
        app => $app,
        client => sub {
            my $cb = shift;
            my $req = HTTP::Request->new(GET => 'https://localhost/');
            $req->header(@$header);
            my $res = $cb->($req);
            my $env = Storable::thaw($res->content);
            is $env->{'psgi.url_scheme'}, 'http', $header->[0] . ' header can disable HTTPS';
        },
    ;
}

