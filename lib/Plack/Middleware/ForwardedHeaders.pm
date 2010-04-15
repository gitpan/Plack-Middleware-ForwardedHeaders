package Plack::Middleware::ForwardedHeaders;
use 5.008;
use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(trusted);
our $VERSION = 0.001;

sub call {
    my ($self, $env) = @_;

    if ($self->trusted) {
        my $trusted = $self->trusted;
        $trusted = [ $trusted ]
            unless ref $trusted;
        my $remote_addr = $env->{REMOTE_ADDR};
        my $passed;
        for my $addr (@$trusted) {
            if ($remote_addr eq $addr) {
                $passed = 1;
                last;
            }
        }
        if (! $passed) {
            return $self->app->($env);
        }
    }

    if (
           lc $env->{HTTP_X_FORWARDED_PROTO} eq 'https'
        || lc $env->{HTTP_X_FORWARDED_SCHEME} eq 'https'
        || lc $env->{HTTP_X_FORWARDED_SSL} eq 'on'
        || lc $env->{HTTP_FRONT_END_HTTPS} eq 'on'
    ) {
        $env->{ORIGINAL_HTTPS} = $env->{HTTPS};
        $env->{HTTPS} = 'on';
        $env->{'original.psgi.url_scheme'} = $env->{'psgi.url_scheme'};
        $env->{'psgi.url_scheme'} = 'https';
    }

    my $forwarded_addr
        = $env->{HTTP_X_FORWARDED_FOR}
        || $env->{HTTP_X_FORWARDED_HOST}
        || $env->{HTTP_X_REAL_IP}
        ;

    if ($forwarded_addr) {
        $forwarded_addr =~ s/\A.*,//;
        $forwarded_addr =~ s/\s+$//;
        $forwarded_addr =~ s/^\s+//;
        $env->{ORIGINAL_REMOTE_ADDR} = $env->{REMOTE_ADDR};
        $env->{REMOTE_ADDR} = $forwarded_addr;
    }

    $self->app->($env);
}

1;

__END__

=head1 NAME

Plack::Middleware::ForwardedHeaders - Use headers from reverse proxy

=head1 SYNOPSIS

    use Plack::Builder;
    builder {
        enable 'ForwardedHeaders';
        $app;
    };

=head1 DESCRIPTION

Uses forwarded headers to determine remote IP address and HTTPS
status.  It will adjust the C<REMOTE_ADDR>, C<HTTPS>, and
C<psgi.url_scheme> environment items accordingly.  The original
values are stored in C<ORIGINAL_REMOTE_ADDR>, C<ORIGINAL_HTTPS>,
and C<original.psgi.url_scheme>.

WARNING: Enabling this middleware without a reverse proxy or a
properly configured list of trusted proxies will allow users to
spoof their IP address.

=head1 CONFIGURATION

=over 4

=item trusted

An IP address or an array reference of IP addresses of trusted
proxies.  If set, the forwarded headers will only be used if the
request comes from one of the addresses listed as trusted.

=back

=head1 HTTP HEADERS

=head2 Remote Address Headers

The folling headers are used to determine the remote IP address for
a forwarded request.

=over 4

=item X-Forwarded-For

=item X-Forwarded-Host

=item X-Real-IP

=back

=head2 HTTPS Headers

The folling headers are used to determine if it a forwarded HTTPS
request:

=over 4

=item X-Forwarded-Proto

=item X-Forwarded-SSL

=item X-Forwarded-Sheme

=item Front-End-Ssl

=back

=cut

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut
