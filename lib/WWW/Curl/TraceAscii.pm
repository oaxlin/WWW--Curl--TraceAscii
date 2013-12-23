package WWW::Curl::TraceAscii;
use strict;
use warnings;
use bytes;
use WWW::Curl::Easy;
use Time::HiRes qw(gettimeofday);

=head1 NAME

WWW::Curl::TraceAscii - Perl extension interface for libcurl

=head1 SYNOPSIS

    use WWW::Curl::TraceAscii;
    my $response;
    my $post = "some post data";
    my $curl = WWW::Curl::TraceAscii->new;
    $curl->setopt(CURLOPT_POST, 1);
    $curl->setopt(CURLOPT_POSTFIELDS, $post);
    $curl->setopt(CURLOPT_URL,'http://www.google.com/');
    $curl->setopt(CURLOPT_WRITEDATA,\$response);
    $curl->perform;

    my @headers = $curl->headers;

    my $trace_ascii = $curl->trace_ascii;

=head1 DESCRIPTION

WWW::Curl::TraceAscii adds additional debugging helpers to WWW::Curl::Easy

=head1 DOCUMENTATION

This module uses WWW::Curl::Easy at it's base.  WWW::Curl::TraceAscii gives you the ability to record a log of your curl connection much like the --trace-ascii feature inside the curl binary.

=head2 WHY DO I NEED A TRACE?

I've been curling pages for decades.  Usually in an automatic fashion.  And while you can write code that will handle almost all failures.  You can't answer the question that will inevitably be asked... What happened??

I've seen hundreds of different types of errors come through that without a good trace would have been impossible to get a difinitive answer as to what happened.

I've personally gotten into the practice of storing the trace data for all connections.  This allows me to review exactly what happened, even if the problem was only temporary.  Especially if the problem was fixed before I was able to review it.

=head1 ADDITIONAL METHODS

New methods added above what is normally in WWW::Curl::Easy.

=cut

sub new {
	my $curl = WWW::Curl::Easy->new(@_);
	my $trace = '',
	my @headers;
	my $hash = {
		curl => $curl,
		headers => \@headers,
		trace_ascii => \$trace,
	};

	my $header_func = sub {
		my ($header) = @_;
		$header =~ s/[\r\n]?[\r\n]$//g;
		push @headers, $header if $header ne '';
		return length($_[0]);
	};

	$curl->setopt(CURLOPT_HEADERFUNCTION,$header_func);
	$curl->setopt(CURLOPT_DEBUGFUNCTION,\&make_trace_ascii);
	$curl->setopt(CURLOPT_DEBUGDATA,\$trace);
	$curl->setopt(CURLOPT_HEADERDATA,\$trace);
	$curl->setopt(CURLOPT_VERBOSE, 1);
	return bless $hash;
}

sub trace_ascii {
	my $self = shift;
	$self->{'trace_ascii'};
}

=head2 headers

Returns the headers from your curl call.

=cut

sub headers {
	my $self = shift;
	@{$self->{'headers'}};
}

=head2 trace_ascii

Mimic the curl binary when you enable the --trace-ascii and --trace-time command line options.  Minus the SSL negotiation data.

=cut

sub setopt {
	my $self = shift;
	$self->{'curl'}->setopt(@_);
}

sub perform {
	my $self = shift;
	$self->{'curl'}->perform(@_);
}

sub stderror {
	my $self = shift;
	$self->{'curl'}->stderror(@_);
}

sub strerror {
	my $self = shift;
	$self->{'curl'}->strerror(@_);
}

sub make_trace_ascii {
	my ($data,$tracePTR,$data_type) =@_;
	my ($seconds, $microseconds) = gettimeofday;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday)=localtime($seconds);

	$$tracePTR .= sprintf('%02d:%02d:%02d.%d ',$hour,$min,$sec,$microseconds);
	my $l = length($data);

	if ($data_type == 0) {
		$$tracePTR .= "== Info: ".$data;
	} elsif ($data_type == 1) {
		$data =~ s/\r?\n$//;
		$$tracePTR .= sprintf("<= Recv header, %d bytes (0x%x)\n",$l,$l)._format_debug_data($data);
	} elsif ($data_type == 2) {
		$data =~ s/\r?\n$//;
		$$tracePTR .= sprintf("=> Send header, %d bytes (0x%x)\n",$l,$l)._format_debug_data($data);
	} elsif ($data_type == 3) {
		$$tracePTR .= sprintf("<= Recv data, %d bytes (0x%x)\n",$l,$l)._format_debug_data($data,1);
	} elsif ($data_type == 4) {
		$$tracePTR .= sprintf("=> Send data, %d bytes (0x%x)\n",$l,$l)._format_debug_data($data,1);
	} else {
		# not sure what any of these values would be, but just in case
		$$tracePTR .= "== Unknown $data_type: ".$data;
	}
	return 0;
}

sub _format_debug_data {
	my ($data,$mask_returns) = @_;
	my $c = 0;
	my $a = $mask_returns ? [$data] : [split /\r\n/, $data, -1];
	$a->[0] = '' unless scalar(@$a);
	my $text = '';
	foreach my $bit ( @$a ) {
		my @array = unpack '(a64)*', $bit;
		$array[0] = '' unless scalar(@array);
		foreach my $line ( @array ) {
			$line =~ s/[^\ -\~]/./ig;
			my $len = bytes::length($line);
			$line = sprintf('%04x: ',$c).$line;
			$c+=2 unless $mask_returns; # add they \r\n back in
			$c+=$len;
		}
		$text .= (join "\n",@array)."\n";
	}
	$text;
}

1;
