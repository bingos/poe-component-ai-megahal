use Test::More tests => 5;
BEGIN { use_ok('POE::Component::AI::MegaHAL') };
use POE;
use Data::Dumper;

my $self;

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
  $poe_kernel->post( $self->session_id => do_reply => { event => '_got_reply', text => 'Hello world!' } );
  undef;
}

sub got_reply {
  pass('Blah2');
  $poe_kernel->call( $self->session_id => 'shutdown' );
  undef;
}
