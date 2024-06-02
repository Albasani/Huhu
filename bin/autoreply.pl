#!/usr/bin/perl -sw
######################################################################
#
# $Id: autoreply.pl 288 2011-02-18 22:45:59Z alba $
#
# Copyright 2007 - 2009 Roman Racine
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

use Mail::Sendmail();
use MOD::DBIUtils();
use MOD::Utils();

# Mail::Sendmail can handle Cc: and produces a detailed log
# Mail::Mailer is inferior, don't use


######################################################################
sub get_strings($)
######################################################################
{
  my $r_config = shift || die;

  my $lang = MOD::Utils::get_translator_language(
    $r_config->{'html_language'},
    undef
  );
  if ($::debug) { printf "get_translator_language=%s\n", $lang; }
  my $trans = MOD::Utils::get_translator($lang);

  my %result = map { $_ => $trans->($_); }
  (
    '_ARRIVAL_NOTICE_BODY',
    '_ARRIVAL_NOTICE_SUBJECT'
  );
  if ($::debug)
  {
    while(my ($key, $value) = each %result)
      { printf "%s => [%s]\n", $key, $value; }
  }
  return \%result;
}

######################################################################
sub send_autoreply($$$)
######################################################################
{
  my $r_config = shift || die;
  my $r_strings = shift || die;
  my $address = shift;

  chomp $address;
  return if ($address =~ /(,|\n)/s);

  my $moderated_group = $r_config->{'moderated_group'};
  Mail::Sendmail::sendmail(
    'From' => $r_config->{'mailfrom'},
    'Subject' => sprintf(
      $r_strings->{_ARRIVAL_NOTICE_SUBJECT},
      $moderated_group
    ),
    'To' => $address,
    'Message' => sprintf(
      $r_strings->{_ARRIVAL_NOTICE_BODY},
      $moderated_group
    ),
  );
  if ($::debug) { print $Mail::Sendmail::log, "\n\n"; }
}

######################################################################
# MAIN
######################################################################

$::debug = 0 if (!$::debug);

die "Missing parameter '-config'" unless($::config);
my %config = MOD::Utils::read_private_config($::config);
my $dbi = MOD::DBIUtils->new(\%config);

my $r_strings = get_strings(\%config);
my $address_rx = $Mail::Sendmail::address_rx;

my $dataref = $dbi->select_pending();
while (my $ref = $dataref->fetchrow_arrayref)
{
  my ($address) = @{$ref};
  if ($address =~ /$address_rx/o)
  {
    # my $address = $1;
    # my $user = $2;
    # my $domain = $3;
    if ($::debug) { printf "processing [%s]\n", $address; }
    send_autoreply(\%config, $r_strings, $address);
  }
  elsif ($::debug) {
    printf "invalid address [%s]\n", $address;
  }
}

######################################################################
