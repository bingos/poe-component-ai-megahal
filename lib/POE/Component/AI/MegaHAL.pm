package POE::Component::AI::MegaHAL;

use AI::MegaHAL;
use POE 0.31 qw(Wheel::Run Filter::Line Filter::Reference);
use Carp;
use vars qw($VERSION);

$VERSION = '0.89';

sub spawn {
  my ($package) = shift;
  my %params = @_;

  foreach my $key ( keys %params ) {
	$params{ lc ( $key ) } = delete( $params{ $key } );
  }

  $params{'autosave'} = 1 unless ( defined ( $params{'autosave'} ) and $params{'autosave'} == 0 );

  my $options = delete ( $params{'options'} );

  my $self = bless \%params, $package;

  $self->{session_id} = POE::Session->create(
	object_states => [
		$self => {
			do_reply => '_megahal_function',
			initial_greeting => '_megahal_function',
		},
		$self => [ qw(_child_closed _child_error _child_stderr _child_stdout _start shutdown) ],
	],
	( ref ( $options ) eq 'HASH' ? ( options => $options ) : () ),
  )->ID();

  return $self;
}

sub session_id {
  return $_[0]->{session_id};
}

sub _megahal_function {
  my ($kernel,$self,$state) = @_[KERNEL,OBJECT,STATE];
  my $sender = $_[SENDER]->ID();

  return if ( $self->{shutdown} );
  my $args;
  if ( ref( $_[ARG0] ) eq 'HASH' ) {
	$args = { %{ $_[ARG0] } };
  } else {
	warn "first parameter must be a hashref, trying to adjust. "
		."(fix this to get rid of this message)";
	$args = { @_[ARG0..$#_] };
  }

  unless ( $args->{event} ) {
	warn "where am i supposed to send the output?";
	return;
  }


  if ( $state eq 'do_reply' and not defined ( $args->{text} ) ) {
	return;
  }

  if ( $state eq 'initial_greeting' and defined ( $args->{text} ) ) {
	delete ( $args->{text} );
  }
  
  $args->{sender} = $sender;

  $args->{func} = $state;
  $kernel->refcount_increment( $sender => __PACKAGE__ );
  $args->{sender} = $sender;

  if ( defined ( $self->{wheel} ) ) {
	$self->{wheel}->put( $args );
  }
  undef;
}

sub _start {
  my ($kernel,$self) = @_[KERNEL,OBJECT];

#  $self->{session_id} = $_[SESSION]->ID();

  if ( $self->{alias} ) {
	$kernel->alias_set( $self->{alias} );
  } else {
	$kernel->refcount_increment( $self->{session_id} => __PACKAGE__ );
  }

  $self->{wheel} = POE::Wheel::Run->new(
	Program => \&main,
	ProgramArgs => [ AutoSave => $self->{autosave}, Path => $self->{path} ],
	ErrorEvent => '_child_error',
	CloseEvent => '_child_closed',
	StdoutEvent => '_child_stdout', 
	StderrEvent => '_child_stderr',
	StdioFilter => POE::Filter::Reference->new(),
	StderrFilter => POE::Filter::Line->new(),
	( $^O eq 'MSWin32' ? ( CloseOnCall => 0 ) : ( CloseOnCall => 1 ) ),
  );
  
  return;
}

sub _child_closed {
  delete ( $_[OBJECT]->{wheel} );
  undef;
}

sub _child_error {
  delete ( $_[OBJECT]->{wheel} );
  undef;
}

sub _child_stderr {
  my ($kernel,$self,$input) = @_[KERNEL,OBJECT,ARG0];

  warn $input . "\n" if ( $self->{debug} );
  undef;
}

sub _child_stdout {
  my ($kernel,$self,$input) = @_[KERNEL,OBJECT,ARG0];
  my $sender = delete( $input->{sender} );
  my $event = delete( $input->{event} );
  $kernel->refcount_decrement( $sender => __PACKAGE__ );
  $kernel->post( $sender => $event => $input );
  undef;
}

sub shutdown {
  my ($kernel,$self) = @_[KERNEL,OBJECT];

  $kernel->alias_remove( $_ ) for $kernel->alias_list();

  unless ( $self->{alias} ) {
	$kernel->refcount_decrement( $self->{session_id} => __PACKAGE__ );
  }

  $self->{shutdown} = 1;
  #$self->{wheel}->kill(9);
  $self->{wheel}->shutdown_stdin;
  delete $self->{wheel};
  undef;
}

sub main {
  my (%params) = @_;
  if ( $^O eq 'MSWin32' ) {
     binmode(STDIN); binmode(STDOUT);
  }
  my $raw;
  my $size = 4096;
  my $filter = POE::Filter::Reference->new();
  my $megahal;
  eval {
  	$megahal = AI::MegaHAL->new( %params );
  };

  if ( $@ ) {
	print STDERR $@ . "\n";
	return;
  }

  while ( sysread ( STDIN, $raw, $size ) ) {
    my $requests = $filter->get( [ $raw ] );
    foreach my $req ( @{ $requests } ) {
	_process_requests( $megahal, $req, $filter );
    }
  }
  $megahal->_cleanup() if ( $params{'AutoSave'} );
  $megahal->DESTROY;
}

sub _process_requests {
  my ($megahal,$req,$filter) = @_;

  my $func = $req->{func};
  $req->{reply} = $megahal->$func( $req->{text} );
  my $response = $filter->put( [ $req ] );
  print STDOUT @$response;
}

1;

__END__

=head1 NAME

POE::Component::AI::MegaHAL -- A non-blocking wrapper around L<AI::MegaHAL|AI::MegaHAL>.

=head1 SYNOPSIS

    use POE qw(Component::AI::MegaHAL);

    my $poco = POE::Component::AI::MegaHAL->spawn( autosave => 1, debug => 0, 
					      	   path => '.', options => { trace => 1 } );

    POE::Session->create(
	package_states => [
		'main' => [ qw(_start _got_reply) ],
	],
    );

    $poe_kernel->run();
    exit 0;

    sub _start {
	$_[KERNEL]->post( $poco->session_id() => do_reply => { text => 'What is a MegaHAL ?', event => '_got_reply' } );
	undef;
    }

    sub _got_reply {
	print STDOUT $_[ARG0]->{reply} . "\n";
	$_[KERNEL]->post( $poco->session_id() => 'shutdown' );
	undef;
    }

=head1 DESCRIPTION

POE::Component::AI::MegaHAL provides a non-blocking wrapper around L<AI::MegaHAL|AI::MegaHAL>. 

=head1 METHODS

=over 

=item spawn

Accepts a number of arguments. 'autosave' and 'path' are passed to L<AI::MegaHAL|AI::MegaHAL>; 'debug' sets the debug mode;
'options' is a hashref of parameters to pass to the component's L<POE::Session|POE::Session>. 'alias', is supported for 
using L<POE::Kernel|POE::Kernel> aliases.

=item session_id

Returns the component session id.

=back

=head1 INPUT

These are the events that we'll accept. 

Both events accept a hashref as the first parameter. You must specify 'event' as the event in your session where you 
want the response to go. See the example in the SYNOPSIS.

The 'shutdown' event doesn't require any parameters.

=over

=item intial_greeting

Solicits the initial greeting returned by the brain on start-up.

=item do_reply

Submits text to the brain and solicits a reply.
In the hashref you must specify 'text' with the data you wish to submit to the L<AI::MegaHAL|AI::MegaHAL> object.

=item shutdown

Shuts the component down gracefully. Any pending requests will be serviced and return events dispatched.

=back

=head1 OUTPUT

Events generated by the component in response to the above input will have a hashref as ARG0. $hashref->{reply} 
will contain the applicable response from the brain.

=head1 AUTHOR

Chris 'BinGOs' Williams

with contributions by David Davies <xantus>.

=head1 SEE ALSO

L<AI::MegaHAL|AI::MegaHAL>
L<http://megahal.sourceforge.net/>
L<POE|POE>
