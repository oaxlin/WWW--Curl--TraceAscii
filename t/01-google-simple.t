#!/usr/bin/perl
use strict;
use warnings;

use Test::More tests => 3;

use WWW::Curl::TraceAscii;
my $response;
my $curl = WWW::Curl::TraceAscii->new;
$curl->setopt(CURLOPT_URL,'http://www.google.com/');
$curl->setopt(CURLOPT_WRITEDATA,\$response);
$curl->perform;

like  ($response, qr/<\!DOCTYPE.*<html.*/is, 'Testing that an HTML page was returned');

my $trace_ascii = eval { $curl->trace_ascii };
like  ($$trace_ascii, qr/== Info: Connection #0 to host .*? left intact/, 'Testing that trace_ascii was populated');

my @headers = eval{ $curl->trace_headers };
cmp_ok(scalar(@headers), '>', 0, 'Testing header returned');