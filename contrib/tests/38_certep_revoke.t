#!/usr/bin/perl

use lib qw(../lib);
use strict;
use warnings;
use JSON;
use English;
use Data::Dumper;
use Log::Log4perl qw(:easy);
use TestCGI;
use IO::Socket::SSL;
use LWP::UserAgent;

Log::Log4perl->easy_init($DEBUG);
#Log::Log4perl->easy_init($ERROR);

use Test::More tests => 2;

package main;

my $result;
my $client = TestCGI::factory('democa');

# create temp dir
-d "tmp/" || mkdir "tmp/";

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";

my $ssl_opts = {
    verify_hostname => 0,
    SSL_key_file => 'tmp/pkiclient.key',
    SSL_cert_file => 'tmp/pkiclient.crt',
    SSL_ca_file => 'tmp/chain.pem',
};
$ua->ssl_opts( %{$ssl_opts} );

# strip header and footer line
#my $pkcs10 = `openssl req -new -subj "/" -nodes -keyout /dev/null 2>/dev/null`;
#$pkcs10 =~ s/^.*-----BEGIN[^-]+-----(.*)-----END[^-]+-----/$1/mxs;

my $response = $ua->post('https://localhost/certep/generic', { revoke => '0x1234556789', reasonCode => 1 } );

ok($response->is_success);

my $body = $response->decoded_content;

# immediate response
ok($body =~ m{<Code>0</Code>});
