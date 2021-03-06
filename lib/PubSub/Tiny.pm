#!/usr/bin/perl
# PubSub::Tiny
# A tiny blocking pub/sub event implementation for perl
# Copyright (C) Eskild Hustvedt 2012
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.14.2 or,
# at your option, any later version of Perl 5 you may have available.

package PubSub::Tiny;
use 5.010;
use Moo;
use Carp qw(croak);

our $VERSION = '0.1';

has '__subscribers' => (
    is => 'ro',
    default => sub { {} },
);

has 'strict' => (
    is => 'ro',
    default => sub { 0 },
);

sub register
{
    my $self = shift;
    if (! $self->strict)
    {
        return;
    }

    if (@_ < 1)
    {
        croak('PubSub::Tiny: Invalid number of parameters to register()');
    }

    foreach my $event(@_)
    {
        if (!defined $event)
        {
            croak('PubSub::Tiny: Got an undef event');
        }
        if ($self->registered($event))
        {
            croak('PubSub::Tiny: Attempted to register an event that has already been registered: '.$event);
        }

        $self->__subscribers->{$event} = [];
    }
}

sub registered
{
    my $self = shift;
    my $event = shift;
    if (!$self->strict)
    {
        return 1;
    }
    if (!defined $event)
    {
        croak('PubSub::Tiny: Invalid number of parameters to registered()');
    }
    if(defined $self->__subscribers->{$event} || $event eq '*')
    {
        return 1;
    }
    return;
}

sub publish
{
    my $self = shift;

    if (@_ < 1)
    {
        croak('PubSub::Tiny: Invalid number of parameters to publish()');
    }

    my $event = shift;
    my $data = shift;

    if(!defined($event))
    {
        croak('PubSub::Tiny: No event name supplied');
    }
    if (! $self->registered($event))
    {
        croak('PubSub::Tiny: Attempt to publish unregistered event "'.$event.'"');
    }

    my $subscribers = $self->__subscribers->{$event};
    if(defined $subscribers)
    {
        foreach my $subscriber (@{$subscribers})
        {
            if(defined $subscriber)
            {
                $subscriber->($data);
            }
        }
    }
    if ($event ne '*')
    {
        $self->publish('*',{ event => $event, data => $data });
    }
    return 1;
}

sub subscribe
{
    my $self = shift;

    if (@_ != 2)
    {
        croak('PubSub::Tiny: Invalid number of parameters to subscribe()');
    }

    my $event = shift;
    my $callback = shift;

    if(!defined($event))
    {
        croak('PubSub::Tiny: No event name supplied');
    }
    if (! $self->registered($event))
    {
        croak('PubSub::Tiny: Attempt to subscribe to unregistered event "'.$event.'"');
    }

    $self->__subscribers->{$event} //= [];
    push(@{ $self->__subscribers->{$event} }, $callback);

    return { _int => scalar @{ $self->__subscribers->{$event} } -1, _event => $event, _valid => 1 };
}

sub unsubscribe
{
    my $self = shift;
    my $data = shift;

    if (!$data || ref($data) ne 'HASH' || !defined($data->{_event}) || !defined($data->{_int}))
    {
        croak('PubSub::Tiny: Invalid parameter supplied');
    }
    if (!$data->{_valid})
    {
        croak('PubSub::Tiny: Attempting to unsubscribe something that has already been unsubscribed');
    }

    $self->__subscribers->{$data->{_event}}->[$data->{_int}] = undef;

    $data->{_valid} = 0;
    delete($data->{_int});
    delete($data->{_event});

    return 1;
}

1;
__END__
=head1 NAME

PubSub::Tiny - A tiny blocking pub/sub event implementation for perl

=head1 SYNOPSIS

  use PubSub::Tiny;
  my $pubSub = PubSub::Tiny->new;
  $pubSub->subscribe('myEvent',sub { });
  $pubSub->publish('myEvent','eventData');

=head1 DESCRIPTION

PubSub::Tiny is a tiny implementation of a pub/sub event system in perl.
It's meant to allow decoupling within an application, and does not do any
permanent storage, nor does it allow any kind of IPC.

=head1 STRICT-MODE

Strict-mode is off by default. When enabled it will require you to take
additional care when publishing and subscribing to events. The methods
"register" and "registered" are only useful in strict mode.

Enabling strict-mode will make PubSub::Tiny require that any event is
"register()ed" before it is published or subscribed to. If strict mode is
active and someone tries to publish or subscribe to a an unregistered
event, it will die.

=head1 METHODS

=head2 HANDLE = $object->subscribe(EVENT, CALLBACK)

Subscribe to the supplied EVENT with CALLBACK. Whenever something publishes
said event your callback will be called. If the event was published with
some data, that will be provided to your callback as its first parameter.

The returned HANDLE variable can be supplied ti the unsubscribe() method
if you want to stop listening to the event.

See the EVENT NAMING section for information about naming events.

Strict mode only: Will die if EVENT has not been registered.

=head2 $object->unsubscribe(HANDLE)

Unsubscribe from an event. HANDLE is the value that gets returned from
subscribe() and is unique for each subscription. If you attempt to
unsubscribe multiple times, it will die with an error.

=head2 $object->publish(EVENT, DATA)

Publish an event, calling all listeners for the event in turn. If you
supply a second DATA parameter, that will be provided as a parameter for
each listeners callback function.

Strict mode only: Will die if EVENT has not been registered.

=head2 Strict mode: $object->register(EVENT1, EVENT2, ..)

When in strict mode, register one or more events. This declares your intention
to publish to said event(s) in the future. If strict mode is not active,
this is a no-op.

=head2 Strict mode: $object->registered(EVENT)

When in strict mode, returns true if an event has been registered, false otherwise.
If strict mode is not active this will always return true.

=head1 EVENT NAMING

In general I<PubSub::Tiny> does not enforce any kind of event naming scheme.
You're free to use whichever naming convention you're comfortable with, with
whichever characters you want. The only special event is "*", which is described
below.

=head2 THE SPECIAL * EVENT

"*" (without the quotes) is the only special event name in PubSub::Tiny.
Subscribers to * will get called on EVERY EVENT. Its data parameter is in the
form:

    { event => REAL_EVENT, data => REAL_DATA }

Where REAL_EVENT is the name of the event that is actually being published, and
REAL_DATA is the data that was passed along with that event (if any).

Note that * is dispatched last in the call chain, so if a callback higher up
in the chain dies, it will not be called (see DISPATCH ORDER).

=head1 DISPATCH ORDER

When you publish an event, each subscriber will be called in turn. The order
in which they are called is the order in which they subscribed, so the first
subscriber will be called first, then the second and so on. Listeners to * are
always called after listeners to the event itself, but in the order that
they subscribed to *.

=head1 EXCEPTION HANDLING

PubSub::Tiny does NO exceptions handling. If a callback dies, then the chain
will get interrupted, and any subscribers that would have been called after
the one that died will not get called, and the die will propagate up to
your code, so it will be your responsibility to properly handle these.

=head1 EXPORT

Nothing

=head1 AUTHOR

Eskild Hustvedt, E<lt>zerodogg@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Eskild Hustvedt

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
