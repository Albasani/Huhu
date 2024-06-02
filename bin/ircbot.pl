#!/usr/bin/perl -sw
######################################################################
#
# $Id: ircbot.pl 266 2010-05-18 15:14:08Z alba $
#
# Copyright 2009 Roman Racine
# Copyright 2010 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
use strict;
use warnings;

use Carp qw(confess);
use Data::Dumper;
use Net::IRC();

use MOD::DBIUtilsPublic();
use MOD::Utils();
use MOD::Displaylib();
use MOD::NotificationSocket();

######################################################################

use constant DEBUG_TO_IRC => 0;
use constant MIN_TIME_BETWEEN_QUERIES => 5;
use constant MAX_TIME_BETWEEN_QUERIES => 30;

######################################################################

my Net::IRC $irc;
my Net::IRC::Connection $conn;
my MOD::DBIUtilsPublic $db;
my MOD::Displaylib $display;

my $channel;
my $last = 'none';
my $pending = 'no';
my $last_query_time = 0;

######################################################################
sub on_connect
######################################################################
{
    my $self = shift;
    $self->join($channel);
    $conn->privmsg($channel,'*huhu*');
    check_for_new(1);
}

######################################################################
sub alarm_handler
######################################################################
{
    check_for_new(1);
    alarm(MAX_TIME_BETWEEN_QUERIES);
}

######################################################################
sub on_public
######################################################################
{
  my ($self, $event) = @_;
  my $msg = ($event->args)[0];
  if ($msg eq '!pending') {
    eval { print_pending(1); };
    warn $@ if ($@);
  }
}

######################################################################
sub on_disconnect
######################################################################
{
  my ($self, $event) = @_;
  while (1) {
    eval {
    $self->connect();
    }; if ($@) {
      sleep 60;
    } else {
      last;
    }
  }
}

######################################################################
sub do_connect($$)
######################################################################
{
  my $config = shift || confess;
  my Net::IRC $irc = shift || confess;

  my $nick     = $config->{'ircbot_nick'};
  my $realname = $config->{'ircbot_realname'};
  my $username = $config->{'ircbot_username'};
  my $server   = $config->{'ircbot_server'};
  my $port     = $config->{'ircbot_port'};

  my $conn = $irc->newconn(
    Nick    => $nick,
    Server  => $server,
    Port    => $port,
    Ircname => $realname,
  );
  confess if (!defined($conn));

  $conn->add_global_handler('376', \&on_connect); 
  $conn->add_global_handler('public', \&on_public);
  $conn->add_global_handler('disconnect', \&on_disconnect);
  return $conn;
}

######################################################################
sub on_socket_read($)
######################################################################
{
  my $read_socket = shift || confess;

  my $buffer;
  my $rc = sysread($read_socket, $buffer, 512);

  if (!defined($rc))
  {
    if (DEBUG_TO_IRC) { $conn->privmsg($channel, "on_socket_read $!"); }
    return;
  }
  
  if ($rc == 0)
  {
    if (DEBUG_TO_IRC) { $conn->privmsg($channel, 'on_socket_read close'); }

    # Do not call close($read_socket), this will hang the process.
    # Socket is automatically closed when the last reference is freed.
    $irc->removefh($read_socket) || confess;
    return;
  }

  $buffer =~ s/\s+$//;
  $conn->privmsg($channel, "sysread=$rc [$buffer]");
  if ($last_query_time + MIN_TIME_BETWEEN_QUERIES < time())
  {
    check_for_new(0);
  }
}

######################################################################
sub on_socket_accept($)
######################################################################
{
  my $accept_socket = shift || confess;

  if (DEBUG_TO_IRC)
  {
    $conn->privmsg($channel, 'on_socket_accept');
  }

  my $new_socket;
  accept($new_socket, $accept_socket) || die "accept: $!";
  defined($new_socket) || die 'defined($new_socket)';
  $irc->addfh($new_socket, \&on_socket_read, 'r') || die "addfh: $!";
}

######################################################################
sub add_notify_sock($$)
######################################################################
{
  my $config = shift || confess;
  my Net::IRC $irc = shift || confess;

  my $fh = MOD::NotificationSocket::socket_create_listening($config);
  if ($fh) { $irc->addfh($fh, \&on_socket_accept, 'r'); }
}
                                                                                
######################################################################
sub print_pending($)
######################################################################
{
  my $verbose = shift;
  my $result = eval
  {
    my @overview = qw(Sender Subject Datum);
    $db->displayrange('pending', 0, 10, \@overview);
  };
  if ($@) { warn $@; return; }
  $last_query_time = time();

  my $ref;
  my $count = 0;
  while ($ref = $result->fetchrow_arrayref) {
    my @columns = @{$ref};
    my ($from,$subject,$date) =  ($display->decode_line($columns[0]),$display->decode_line($columns[1]),
      $columns[2]);
    $conn->privmsg($channel,"$date; $from; $subject");
    sleep 1;
    $count++;
  }
  if (!$count && $verbose) {
    $conn->privmsg($channel,"No postings pending");
  }
}  

######################################################################
sub check_for_new($)
######################################################################
{
  my $verbose = shift;
  my $result = eval
  {
    my @overview = qw(Id Sender Subject Datum);
    $db->displayrange('pending', 0, 1, \@overview);
  };
  if ($@) { warn $@; return; }
  $last_query_time = time();

  my $ref;
  if ($ref = $result->fetchrow_arrayref) {
    my @result = @{$ref};
    if ($last eq 'none' or $last < $result[0]) {
      my ($from,$subject,$date) =  ($display->decode_line($result[1]),$display->decode_line($result[2]),
        $result[3]);
      $conn->privmsg($channel,"New posting: $date; $from; $subject");
      $pending = 'yes';
      $last = $result[0];
    } 
  } elsif ($pending eq 'yes') {
    $conn->privmsg($channel,"No pending postings any more.");
    $pending = 'no';
  }
}    

######################################################################
# main
######################################################################

if ($::pidfile)
{
  my $file;
  if (open($file, '>', $::pidfile))
    { print $file $$, "\n"; }
  else
    { warn "Can't open $::pidfile for writing: $!"; }
}

die "Missing parameter '-config'" unless($::config);
my %config = MOD::Utils::read_private_config($::config);
$channel = $config{'ircbot_channel'} || die;
$db = MOD::DBIUtilsPublic->new(\%config);
$display = MOD::Displaylib->new(\%config,0);

$irc = new Net::IRC;
add_notify_sock(\%config, $irc);
$conn = do_connect(\%config, $irc);

$SIG{'ALRM'} = \&alarm_handler;
alarm(MAX_TIME_BETWEEN_QUERIES);
$irc->start;
