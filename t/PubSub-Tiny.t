use strict;
use warnings;

use Test::More;

plan tests => 55;

use_ok('PubSub::Tiny');

sub tryCatch
{
    my $shouldCrash = shift;
    my $sub = shift;
    my $name = shift;
    eval
    {
        $sub->();
        if ($shouldCrash)
        {
            fail($name);
        }
        else
        {
            pass($name);
        }
    };
    my $e = $@;
    if ($e)
    {
        if ($shouldCrash && $e =~ /^PubSub::Tiny/)
        {
            pass($name);
        }
        else
        {
            fail($name);
        }
    }
}

my $success = 0;
my $successSub = sub { $success++ };

# --
# Testing non-strict mode
# --
{
    # Sanity checking
    my $tinyPubSub = PubSub::Tiny->new;
    ok(defined $tinyPubSub,'->new unsuburned something usable');
    isa_ok($tinyPubSub,'PubSub::Tiny');
    ok(!$tinyPubSub->strict,'Strict should be false by default');
    ok($tinyPubSub->registered('something'),'Everything is "registered"');

    # Basic events
    my $unsub = $tinyPubSub->subscribe('test',$successSub);
    $tinyPubSub->publish('test');
    ok($success,'Event emitted');
    $tinyPubSub->publish('test');
    is($success,2,'Event emitted twice');

    # Unsubscribing
    $success = 0;
    is($unsub->{_valid},1,'unsub data should be valid');
    is($unsub->{_event},'test','event should match');
    is($unsub->{_int},0,'int should be 0');
    $tinyPubSub->unsubscribe($unsub);
    is_deeply($unsub,{ _valid => 0 },'unsub data should no longer be valid');
    $tinyPubSub->publish('test');
    is($success,0,'Event unsubscribed successfully');
    tryCatch(1,sub { $tinyPubSub->unsubscribe($unsub); },'Should not be able to unsubscribe an already-unsubscribed listener');

    # Multiple subscribers
    $unsub = $tinyPubSub->subscribe('secondTest',$successSub);
    $tinyPubSub->subscribe('secondTest',$successSub);
    $tinyPubSub->publish('secondTest');
    is($success,2,'Two secondTest events should have been published');
    $success = 0;
    $tinyPubSub->unsubscribe($unsub);
    $tinyPubSub->publish('secondTest');
    is($success,1,'One secondTest events should have been published');

    # Multiple different subscribers
    $success = [];
    $unsub = $tinyPubSub->subscribe('anotherTest',sub {
            push(@{$success},'first');
        });
    $tinyPubSub->subscribe('anotherTest',sub {
            push(@{$success},'second');
        });
    $tinyPubSub->publish('anotherTest');
    is_deeply($success, [ 'first','second' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub);
    $tinyPubSub->publish('anotherTest');
    is_deeply($success, [ 'second' ]);
}

# --
# Testing strict mode
# --
{
    $success = 0;
    my $specialListenerSuccess = 0;
    my $unsub;
    # Sanity checking
    my $tinyPubSub = PubSub::Tiny->new(strict => 1);
    ok(defined $tinyPubSub,'->new unsuburned something usable');
    isa_ok($tinyPubSub,'PubSub::Tiny');
    ok($tinyPubSub->strict,'Strict should be true');
    ok(!$tinyPubSub->registered('something'),'Everything is not "registered"');
    ok($tinyPubSub->registered('*'),'* is special and should always be registered');

    # Basic events
    my $specialUnsub = $tinyPubSub->subscribe('*',sub {
            $specialListenerSuccess++;
        });
    tryCatch(1,sub { $unsub = $tinyPubSub->subscribe('test',$successSub); },'Should not be able to subscribe to unregistered event');
    $tinyPubSub->register('test');
    $unsub = $tinyPubSub->subscribe('test',$successSub);
    $tinyPubSub->publish('test');
    ok($success,'Event emitted');
    $tinyPubSub->publish('test');
    is($success,2,'Event emitted twice');
    is($specialListenerSuccess,2,'* should have been called twice');

    # Unsubscribing
    $success = 0;
    $tinyPubSub->unsubscribe($unsub);
    $tinyPubSub->publish('test');
    is($success,0,'Event unsubscribed successfully');
    tryCatch(1,sub { $tinyPubSub->unsubscribe($unsub); },'Should not be able to unsubscribe an already-unsubscribed listener');

    # Multiple subscribers
    ok(!$tinyPubSub->registered('secondTest'),'secondTest should not already be registered');
    $tinyPubSub->register('secondTest');
    ok($tinyPubSub->registered('secondTest'),'secondTest has now been registered');
    $unsub = $tinyPubSub->subscribe('secondTest',$successSub);
    $tinyPubSub->subscribe('secondTest',$successSub);
    $tinyPubSub->publish('secondTest');
    is($success,2,'Two secondTest events should have been published');
    $success = 0;
    $tinyPubSub->unsubscribe($unsub);
    $tinyPubSub->publish('secondTest');
    is($success,1,'One secondTest events should have been published');
    is($specialListenerSuccess,5,'* should have been called five times');

    # Multiple different subscribers
    ok(!$tinyPubSub->registered('anotherTest'),'anotherTest should not already be registered');
    $tinyPubSub->register('anotherTest');
    ok($tinyPubSub->registered('anotherTest'),'anotherTest has now been registered');
    $success = [];
    $unsub = $tinyPubSub->subscribe('anotherTest',sub {
            push(@{$success},'first');
        });
    $tinyPubSub->subscribe('anotherTest',sub {
            push(@{$success},'second');
        });
    $tinyPubSub->publish('anotherTest');
    is_deeply($success, [ 'first','second' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub);
    is($specialListenerSuccess,6,'* should have been called six times');
    $tinyPubSub->unsubscribe($specialUnsub);
    $tinyPubSub->publish('anotherTest');
    is($specialListenerSuccess,6,'* should still have been called six times');
    is_deeply($success, [ 'second' ]);
}

# --
# Additional tests (in strict-mode, but most are mode-independant)
# --
{
    $success = undef;
    # Sanity checking
    my $tinyPubSub = PubSub::Tiny->new(strict => 1);
    ok(defined $tinyPubSub,'->new unsuburned something usable');
    isa_ok($tinyPubSub,'PubSub::Tiny');
    ok($tinyPubSub->strict,'Strict should be true');
    ok(!$tinyPubSub->registered('something'),'Everything is not "registered"');

    $tinyPubSub->register('testSub');
    $tinyPubSub->register('dataTest');

    # Event data
    $tinyPubSub->subscribe('dataTest',sub
        {
            $success = shift;
        });
    $tinyPubSub->publish('dataTest','works');
    is($success,'works','Publishing with data works');

    $success = [];
    # Register several different listeners, then unsubscribe each in turn,
    # making sure wrong listeners aren't unsubscribed.
    my $unsub1 = $tinyPubSub->subscribe('testSub',sub {
            push(@{ $success },'unsub1');
        });
    my $unsub2 = $tinyPubSub->subscribe('testSub',sub {
            push(@{ $success },'unsub2');
        });
    my $unsub3 = $tinyPubSub->subscribe('testSub',sub {
            push(@{ $success },'unsub3');
        });
    my $unsub4 = $tinyPubSub->subscribe('testSub',sub {
            push(@{ $success },'unsub4');
        });
    my $unsub5 = $tinyPubSub->subscribe('testSub',sub {
            push(@{ $success },'unsub5');
        });
    $tinyPubSub->publish('testSub');
    is_deeply($success, [ 'unsub1','unsub2','unsub3','unsub4','unsub5' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub3);
    $tinyPubSub->publish('testSub');
    is_deeply($success, [ 'unsub1','unsub2','unsub4','unsub5' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub4);
    $tinyPubSub->publish('testSub');
    is_deeply($success, [ 'unsub1','unsub2','unsub5' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub5);
    $tinyPubSub->unsubscribe($unsub1);
    $tinyPubSub->publish('testSub');
    is_deeply($success, [ 'unsub2' ]);
    $success = [];
    $tinyPubSub->unsubscribe($unsub2);
    $tinyPubSub->publish('testSub');
    is_deeply($success, [ ]);
    is_deeply($tinyPubSub->__subscribers->{'testSub'},[undef,undef,undef,undef,undef]);

    # Ensure parameter validation is working
    tryCatch(1,sub {
        $tinyPubSub->subscribe();
    },'subscribe() should not work without any parameters');
    tryCatch(1,sub {
        $tinyPubSub->unsubscribe();
    },'unsubscribe() should not work without any parameters');
    tryCatch(1,sub {
        $tinyPubSub->register();
    },'register() should not work without any parameters in strict mode');
    tryCatch(1,sub {
        $tinyPubSub->registered();
    },'registered() should not work without any parameters');
    tryCatch(1,sub {
        $tinyPubSub->publish();
    },'publish() should not work without any parameters');
}

done_testing();
