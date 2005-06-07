# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 5;
BEGIN { use_ok('POE::Component::AI::MegaHAL') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

use POE;

my ($self);

POE::Session->create(
	inline_states => {
		_start => \&test_start, 
		_got_reply => \&got_reply,
		_stop => sub { pass('stop'); },
	},
	options => { trace => 0 },
);

$poe_kernel->run();
exit 0;

sub test_start {
	pass('blah');

	$self = POE::Component::AI::MegaHAL->spawn( autosave => 0, debug => 0, options => { trace => 0 } );

	isa_ok ( $self, 'POE::Component::AI::MegaHAL' );
  
	$poe_kernel->post( $self->{session_id} => do_reply => { event => '_got_reply', text => 'Hello world!' } );
	undef;
}

sub got_reply {
	pass('Blah2');
	my ($answer) = $_[ARG0];

	$poe_kernel->call( $self->{session_id} => 'shutdown' );
	undef;
}
