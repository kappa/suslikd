#! /usr/bin/perl
use strict;
use warnings;

package Suslik::Daemon;
use base 'Net::Server::PreFork';

my $TIMEOUT = 30;
my $HOST = 'kapecod';
my $PORT = 70;

my $CRLF = "\x0D\x0A";

sub goph($);
sub gophinp($$);
sub gophend();

sub process_request {
    my $self = shift;

    eval {
        local $SIG{ALRM} = sub { die "Timed out!\n" };
        my $prev_alarm = alarm($TIMEOUT);

        my $str = <STDIN>;
        $str =~ s/$CRLF$//;

        warn 'suslik req - ' . localtime() . ' ' . $self->{server}->{peeraddr} . " [$str]\n";

        my ($selector, $query) = split("\t", $str);
        $selector ||= q{}; $query ||= q{};

        $self->dispatch($selector, $query);

        alarm($prev_alarm);
    };

    if ($@ =~ /Timed out/) {
        goph 'You timed out';
    }
}

our %action = (
    default         => sub {
        goph 'Привет!';
        goph '
        gophinp 'Сказать что-нибудь...' => 'say';
        gophend;
    },
    say             => sub {
        goph "Вы сказали: [$_[0]]";
        gophend;
    },
);

sub dispatch {
    my ($self, $selector, $query) = @_;

    $action{exists $action{$selector} ? $selector : 'default'}->($query);
}

sub goph($) {
    my $str = shift;

    print "i$str\t%\terror.host\t$PORT$CRLF";
}

sub gophend {
    goph ' -- powered by suslikd.pl,v';
    print ".$CRLF";
}

sub gophinp($$) {
    my ($prompt, $action) = @_;
    
    print "7$prompt\t$action\t$HOST\t$PORT$CRLF";
}

package main;

Suslik::Daemon->run(port => $PORT);
exit;
