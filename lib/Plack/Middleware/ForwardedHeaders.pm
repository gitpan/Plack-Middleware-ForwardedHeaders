package Plack::Middleware::ForwardedHeaders;
use 5.008;
use strict;
use warnings;
use parent qw(Plack::Middleware);
use Plack::Util::Accessor qw(trusted use_host use_scheme use_address resolve_host);
use Socket ();
our $VERSION = 0.002;

sub prepare_app {
    my $self = shift;
    defined $self->use_host     or $self->use_host(0);
    defined $self->use_scheme   or $self->use_scheme(1);
    defined $self->use_address  or $self->use_address(1);
}

sub call {
    my ($self, $env) = @_;
    if ($self->check_trusted($env)) {
        $self->set_host($env)
            if $self->use_host;
        $self->set_scheme($env)
            if $self->use_scheme;
        $self->set_address($env)
            if $self->use_address;
    }

    $self->app->($env);
}

sub check_trusted {
    my ($self, $env) = @_;

    my $trusted_addresses = $self->trusted;
    return 1
        unless $trusted_addresses;

    $trusted_addresses = [ $trusted_addresses ]
        unless ref $trusted_addresses;
    my $remote_addr = $env->{REMOTE_ADDR};
    my $passed;
    for my $addr (@$trusted_addresses) {
        if ($remote_addr eq $addr) {
            $passed = 1;
            last;
        }
    }
    return $passed;
}

sub set_scheme {
    my ($self, $env) = @_;
    my $scheme = $env->{HTTP_X_FORWARDED_PROTO} || $env->{HTTP_X_FORWARDED_SCHEME};
    if ( my $https = $env->{HTTP_X_FORWARDED_SSL} || $env->{HTTP_FRONT_END_HTTPS} ) {
        $scheme ||= lc $https eq 'on' ? 'https' : 'http';
    }
    if ($scheme) {
        return $env->{'psgi.url_scheme'} = lc $scheme;
    }
    return;
}

sub set_host {
    my ($self, $env) = @_;
    my $host = $env->{HTTP_X_FORWARDED_HOST};
    if ($host) {
        return $env->{HTTP_HOST} = $host;
    }
    return;
}

sub set_address {
    my ($self, $env) = @_;
    my $forwarded_addr
        = $env->{HTTP_X_FORWARDED_FOR}
        || $env->{HTTP_X_REAL_IP}
        ;

    if ($forwarded_addr) {
        $forwarded_addr =~ s/\A.*,//;
        $forwarded_addr =~ s/\s+$//;
        $forwarded_addr =~ s/^\s+//;
        if ($self->resolve_host) {
            $env->{REMOTE_HOST} = gethostbyaddr(Socket::inet_aton($forwarded_addr), Socket::AF_INET);
        }
        return $env->{REMOTE_ADDR} = $forwarded_addr;
    }
    return;
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

Uses forwarded headers to determine remote IP address, HTTPS status,
and requested host.  It will adjust the C<REMOTE_ADDR>, C<HTTP_HOST>,
and C<psgi.url_scheme> environment items accordingly.

WARNING: Enabling this middleware without a reverse proxy or a
properly configured list of trusted proxies will allow users to
spoof their IP address.

=head1 CONFIGURATION

=over 4

=item trusted

An IP address or an array reference of IP addresses of trusted
proxies.  If set, the forwarded headers will only be used if the
request comes from one of the addresses listed as trusted.

=item use_host

If set, forwarded headers will be used to determine the host being
requested.  Defaults to false.

=item use_scheme

If set, forwarded headers will be used to determine the URL scheme.
Defaults to true.

=item use_address

If set, forwarded headers will be used to determine the client
address.  Defaults to true.

=item resolve_host

If set, the hostname of the client will be resolved and saved in
the REMOTE_HOST.  Defaults to false.

=back

=head1 HTTP HEADERS

=head2 Host Headers

The folling headers are used to determine the original requested
host for a forwarded request.

=over 4

=item X-Forwarded-Host

Set by Apache 2.2

=back

=head2 Remote Address Headers

The folling headers are used to determine the remote IP address for
a forwarded request.

=over 4

=item X-Forwarded-For

The de-facto standard for finding the originating client IP address.
Set by Squid, Apache 2.2, and many others.

=item X-Real-IP

Used by nginx.

=back

=head2 Scheme Headers

The folling headers are used to determine the forwarded scheme:

=over 4

=item X-Forwarded-Proto

=item X-Forwarded-SSL

=item X-Forwarded-Scheme

=item Front-End-HTTPS

Used by Microsoft Internet Security and Acceleration Server

=back

=cut

=head1 SEE ALSO

L<http://en.wikipedia.org/wiki/X-Forwarded-For>

=head1 AUTHOR

Graham Knop <haarg@haarg.org>

=head1 LICENSE

Copyright (c) 2010, Graham Knop

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl 5.10.0. For more details, see the
full text of the licenses in the directory LICENSES.

=cut
