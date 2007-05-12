#! /usr/bin/perl
use strict;
use warnings;

package Suslik::Daemon;
use base 'Net::Server::PreFork';

use DBI;
use Encode;

my $TIMEOUT = 30;
my $HOST = 'kapecod';
my $PORT = 70;
my $WALL_DB = "$ENV{HOME}/work/gopher/wall_db";

my $CRLF = "\x0D\x0A";
my $outer_encoding = 'windows-1251';

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
    default         => \&default_handler,
);

sub default_handler {
    if ($_[1]) {
        write_wall(@_);
    }

    goph 'Привет!';
    goph '';
    goph 'Это Стена, на ней пишут буквы.';
    goph 'Вероятно, это также первый в мире UGC-шный gopher-сайт!';
    goph 'В принципе, русских сайтов в gopher-спейсе тоже примерно ноль.';
    goph 'Ура.';
    goph '';
    goph 'Вот смотрите, чего понаписали:';
    foreach (read_wall()) {
        goph $_;
    }
    goph '';
    gophinp 'Написать ещё букв...' => '';
    goph '(Кстати, не рекомендую вводить русские буквы. От них на Стене образуются некрасивые пятна.)';
    gophend;
}

sub dispatch {
    my ($self, $selector, $query) = @_;

    $action{exists $action{$selector} ? $selector : 'default'}->($self, $query);
}

sub goph($) {
    my $str = shift;

    print "i$str\t%\terror.host\t$PORT$CRLF";
}

sub gophend() {

    goph '' for 1 .. 5;
    goph ' -- powered by suslikd,v1.1';
    print ".$CRLF";
}

sub gophinp($$) {
    my ($prompt, $action) = @_;
    
    print "7$prompt\t$action\t$HOST\t$PORT$CRLF";
}

sub read_wall {
    my $dbh = DBI->connect("dbi:SQLite:dbname=$WALL_DB", q{}, q{});

    my @wall = @{$dbh->selectall_arrayref("select time, who, words from wall order by time")};

    return map {
        my ($time, $who, $words) = @{$_};
        $who =~ /(\w+\.\w+)$/
            and $who = $1;

        '...@' . $who . ': ' . $words;
    } @wall;
}

sub write_wall {
    my ($self, $str) = @_;
    my $dbh = DBI->connect("dbi:SQLite:dbname=$WALL_DB", q{}, q{});

    $dbh->do("insert into wall values (NULL, ?, ?, ?)",
        undef, time(), $self->{server}->{peerhost} || $self->{server}->{peeraddr}, $str);
}

package main;

Suslik::Daemon->run(
    port => $PORT,

    reverse_lookups => 1,
);
exit;
