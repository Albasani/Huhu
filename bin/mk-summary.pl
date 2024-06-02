#!/usr/bin/perl -sw
#######################################################################
#
# $Id: mk-summary.pl 249 2010-02-17 22:42:19Z alba $
#
# Copyright 2010 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
use strict;
use Carp qw(confess);
use MOD::Utils();

######################################################################
sub get_param($)
######################################################################
{
  my $param_name = shift || confess;

  my $r_value;
  {
    # man perlvar
    # $^W ... The current value of the warning switch, initially
    #         true if -w was used.
    local $^W = 0;
    $r_value = eval '*{$::{"' . $param_name . '"}}{"SCALAR"}';
  }
  if (defined($r_value))
  {
    my $value = $$r_value;
    return $value if (defined($value));
  }
  my $var_name = 'HUHU_' . uc($param_name);
  my $value = $ENV{$var_name};
  return $value if (defined($value));
  die "Parameter -$param_name not specified and environment variable $var_name not defined.";
}

######################################################################
# main
######################################################################

die 'Argument -config=file missing' unless($::config);

# supress warnings
$::email_domain = undef unless($::email_domain);
$::www_base_dir = undef unless($::www_base_dir);
$::www_base_url = undef unless($::www_base_url);

my $email_domain = get_param('email_domain');
my $www_base_dir = get_param('www_base_dir');
my $www_base_url = get_param('www_base_url');

my %config = MOD::Utils::read_private_config($::config);

my $MODERATED_GROUP = $config{'moderated_group'} || die;
my $user_name = $MODERATED_GROUP;
$user_name =~ s/\./-/g;
my $SUBMISSION_EMAIL = $user_name . '@' . $email_domain;

my $APPROVE_STRING = $config{'approve_string'} || '';
my $MID_FQDN = $config{'mid_fqdn'} || '';
my $MAILFROM = $config{'mailfrom'} || '';
my $NNTP_USER = $config{'nntp_user'} || '';
my $NNTP_PASS = $config{'nntp_pass'} || '';
my $NNTP_SERVER = $config{'nntp_server'} || '';

print <<EOF;
== Email ==

The submission address is <$SUBMISSION_EMAIL>.

Messages are directly processed by procmail, so you cannot access it
with POP or IMAP. (Messages are saved in a backup directory as plain
files, though.)

You can test Huhu by sending posts directly to this address.
When tests are finished you should send a message stating that
<$SUBMISSION_EMAIL> is the new submission address of
$MODERATED_GROUP to <moderators-request\@isc.org>.

== Web Interface ==

The web interface consists of two parts. The public part is accessible
to everybody. It just displays the approved posts.

   https://albasani.net/huhu/aus/legal/moderated/public.pl

And then there is the private part. This is protected with a login.
using the HTTP digest system.

   https://albasani.net/huhu/aus/legal/moderated/modtable.pl

HTTP digest is safe to use on unencrypted connections, but for additional
paranoia above URLs are also available through https (with a self signed
certificate).

There is currently no way to handle user management through the web
interface. I created one account for you:

Username:
Password:

== Test Mode ==

At the moment this instance of Huhu is in test mode. Approved messages
are sent to albasani.test.moderated.  This is an internal group, i.e.
it is not sent to peers. You need an albasani-account to read it.

When you are satisfied with your tests please give me a note.
I will then switch to $MODERATED_GROUP.

== Configurable Options ==

The following settings are set to default values.
Please give me a note if you want to have them changed.

  # Value of header "Approved:" in posts
  approve_string=$APPROVE_STRING

  # Right hand side of message IDs in in posts.
  # Empty value means that the news server generates the ID.
  mid_fqdn=$MID_FQDN

  # Value of header "From:" in rejection notices.
  mailfrom=$MAILFROM

== Usenet Account ==

Username: $NNTP_USER
Password: $NNTP_PASS
Server  : $NNTP_SERVER

It has permissions to send approved posts to albasani.test.moderated
and $MODERATED_GROUP. Use it to bypass the moderation (e.g. send FAQs
or cancel messages) or to read the internal albasani.* groups.
EOF
