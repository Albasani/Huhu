#!/usr/bin/perl -sw
######################################################################
#
# $Id: NotificationSocket.pm 266 2010-05-18 15:14:08Z alba $
#
# Copyright 2010 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
package MOD::NotificationSocket;

use strict;
use warnings;
use Carp qw( confess );

use Socket qw(
  PF_UNIX
  sockaddr_un
  SOCK_STREAM
  SOMAXCONN
);

######################################################################
sub socket_read($;$$)
######################################################################
{
  my $fh = shift || confess;
  my $on_close = shift;
  my $on_debug_print = shift;

  my $buffer;
  my $rc = sysread($fh, $buffer, 512);

  if (!defined($rc))
  {
    if ($on_debug_print) { &$on_debug_print("socket_read $!"); }
    return undef;
  }
  
  if ($rc == 0)
  {
    if ($on_debug_print) { &$on_debug_print('socket_read close'); }

    if ($on_close) { &$on_close($fh); }
    else { close($fh) || confess; }
    return undef;

    # Do not call close($fh), this will hang the process.
    # Socket is automatically closed when the last reference is freed.
    # $irc->removefh($fh) || confess;
    # return;
  }

  $buffer =~ s/\s+$//;
  if ($on_debug_print) { &$on_debug_print("socket_read rc=$rc buffer=[$buffer]"); }
  return $buffer;
}

######################################################################
sub socket_create_listening($)
######################################################################
{
  my $config = shift || confess;

  my $filename = $config->{'ircbot_notify_sock'};
  return undef if (!$filename);

  unlink($filename);
  my $uaddr = sockaddr_un($filename)  || die "sockaddr_un: $!";
  my $proto = getprotobyname('tcp')   || die "getprotobyname: $!";
  my $fh;
  socket($fh, PF_UNIX,SOCK_STREAM, 0) || die "socket: $!";
  bind  ($fh, $uaddr)                 || die "bind: $!";
  listen($fh, SOMAXCONN)              || die "listen: $!";

  return $fh;
}

######################################################################
1;
######################################################################
