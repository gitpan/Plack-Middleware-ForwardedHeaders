use strict;
use warnings;

use Test::More tests => 11;

use Plack::Test;
use Plack::Middleware::ForwardedHeaders;
use HTTP::Request;
use Storable;

my $app = sub {
    my $env = shift;
    my $output = Storable::freeze({
        map { $_ => $env->{$_} } qw(
            psgi.url_scheme
            original.psgi.url_scheme
            HTTPS
            ORIGINAL_HTTPS
            REMOTE_ADDR
            ORIGINAL_REMOTE_ADDR
        )
    });

    return [200, ['Content-Type' => 'text/plain'], [ $output ] ];
};
$app = Plack::Middleware::ForwardedHeaders->wrap($app);
my $test_app = sub {
    my $env = shift;
    $env->{REMOTE_ADDR} = '127.0.0.1';
    $env->{HTTPS} = 'off';
    $app->($env);
};

for my $header (qw(X-Forwarded-For X-Forwarded-Host X-Real-IP)) {
    test_psgi
        app => $test_app,
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
    app => $test_app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        $req->header('X-Forwarded-For', '100.100.100.100, 200.200.200.200');
        my $res = $cb->($req);
        my $env = Storable::thaw($res->content);
        is $env->{REMOTE_ADDR}, '200.200.200.200', 'X-Forwarded-For uses last of comma separated items';
        is $env->{ORIGINAL_REMOTE_ADDR}, '127.0.0.1', 'Original remote address stored';
    },
;

for my $header (
    ['X-Forwarded-Proto' => 'https'],
    ['X-Forwarded-Scheme' => 'https'],
    ['X-Forwarded-SSL' => 'on'],
    ['Front-End-HTTPS' => 'on'],
) {
    test_psgi
        app => $test_app,
        client => sub {
            my $cb = shift;
            my $req = HTTP::Request->new(GET => 'http://localhost/');
            $req->header(@$header);
            my $res = $cb->($req);
            my $env = Storable::thaw($res->content);
            is $env->{'psgi.url_scheme'}, 'https', $header->[0] . ' header enables HTTPS';
        },
    ;
}

test_psgi
    app => $test_app,
    client => sub {
        my $cb = shift;
        my $req = HTTP::Request->new(GET => 'http://localhost/');
        $req->header('X-Forwarded-Proto', 'https');
        my $res = $cb->($req);
        my $env = Storable::thaw($res->content);
        is $env->{'original.psgi.url_scheme'}, 'http', 'Original psgi.url_scheme setting stored';
        is $env->{'ORIGINAL_HTTPS'}, 'off', 'Original HTTPS setting stored';
    },
;

