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

use Test::More tests => 5;

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
my $pkcs10 = `openssl req -new -subj "/" -nodes -keyout /dev/null 2>/dev/null`;
$pkcs10 =~ s/^.*-----BEGIN[^-]+-----(.*)-----END[^-]+-----/$1/mxs;

my $response = $ua->post('https://localhost/certep/generic', { cn => 'device1234.openxpki.org', 'pkcs10' => $pkcs10 } );

ok($response->is_success);

my $body = $response->decoded_content;

# immediate response
ok($body =~ m{<Code>0</Code>});
ok($body =~ m{<X509-Cert>\s*-----BEGIN CERTIFICATE-----});
ok($body =~ m{<PKCS7-Chain>\s*-----BEGIN CERTIFICATE-----});

my ($wf_id) = $body =~ m{<TransactionID>(\d+)</TransactionID>};
ok($wf_id);
diag("Workflow is $wf_id");

$result = $client->mock_request({
    'page' => 'workflow!load!wf_id!'.$wf_id
});

my $cert_identifier = $result->{main}->[0]->{content}->{data}->[0]->{value}->{label};
$cert_identifier =~ s/\<br.*$//g;

open(CERT, ">tmp/certep.id");
print CERT $cert_identifier;
close CERT;


