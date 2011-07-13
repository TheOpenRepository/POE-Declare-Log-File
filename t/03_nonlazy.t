#!/usr/bin/perl

use strict;
BEGIN {
	$|  = 1;
	$^W = 1;
}

use Test::More tests => 22;
use Test::POE::Stopping;
use File::Spec::Functions ':ALL';
use File::Remove 'clear';
use POE;
use POE::Declare::Log::File ();

# Test event firing order
my $order = 0;
sub order {
	my $position = shift;
	my $message  = shift;
	is( $order++, $position, "$message ($position)" );
}

# Identify the test files
my $file = catfile( 't', '03_nonlazy.1' );
clear($file);
ok( ! -f $file, "Test file $file does not exist" );





######################################################################
# Test Object

my $log = POE::Declare::Log::File->new(
	Filename => $file,
);
isa_ok( $log, 'POE::Declare::Log::File' );
ok( -f $file, 'Log file object without Lazy opens file immediately' );





######################################################################
# Test Session

# Set up the test session
POE::Session->create(
	inline_states => {

		_start => sub {
			# Start the server
			order( 0, 'Fired main::_start' );

			$_[KERNEL]->delay_set( startup => 1 );
			$_[KERNEL]->delay_set( running => 2 );
			$_[KERNEL]->delay_set( flushed => 3 );
			$_[KERNEL]->delay_set( stopped => 4 );
			$_[KERNEL]->delay_set( timeout => 5 );
		},

		startup => sub {
			order( 1, 'Fired main::startup' );

			# Start the log stream
			ok( exists $log->{buffer}, 'Buffer exists' );
			ok( ! defined $log->{buffer}, 'Buffer is empty' );
			is( $log->{state}, 'STOP', 'STOP' );
			ok( $log->start, '->start ok' );
		},

		running => sub {
			order( 2, 'Fired main::running' );

			# Are we started?
			is( $log->{state}, 'IDLE', 'IDLE' );

			# Send a message
			ok( $log->print("Message"), '->print ok' );
			is( $log->{buffer}, "Message\n" );
		},

		flushed => sub {
			order( 3, 'Fired main::flushed' );

			# Are we back to idle again
			is( $log->{state}, 'IDLE', 'IDLE' );
			ok( exists $log->{buffer}, 'Buffer exists' );
			ok( ! defined $log->{buffer}, 'Buffer is empty' );

			# Stop the service
			ok( $log->stop, '->stop ok' );
		},

		stopped => sub {
			order( 4, 'Fired main::stopped' );
			is( $log->{state}, 'STOP', 'STOP' );
		},

		timeout => sub {
			order( 5, 'Fired main::timeout' );
			poe_stopping();
		},
	},
);

POE::Kernel->run;
