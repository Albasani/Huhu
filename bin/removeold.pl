#!/usr/bin/perl
######################################################################
#
# $Id: removeold.pl 148 2009-10-13 15:02:22Z alba $
#
# Copyright 2007 - 2009 Roman Racine
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
use MOD::Utils();
use MOD::DBIUtils();
use MOD::Spamfilter();

my %config = MOD::Utils::read_private_config($ARGV[0]);
my $dbi = MOD::DBIUtils->new(\%config) || confess;

{
  #Zeige Postings an, die zwischen 0 und 1 Tagen alt sind
  #und den Status 'moderated' haben.
  my $dataref = $dbi->select_old_postings(0,1,'moderated');
  while (my $ref = $dataref->fetchrow_arrayref) {
    my ($id,$posting) = @{$ref};
    #Fuettere sie an Spamassassin als Ham (kein Spam)
    MOD::Spamfilter::spamlearn($posting,0);
  }
}

#Zeige Postings an, die aelter als x Tage sind und den
#Status 'spam' tragen, d.h. in den letzten x Tagen
#entweder von einem Moderator als Spam klassifiziert
#worden sind oder bereits als Spam erkannt wurden, ohne
#dass ein Moderator sie im Nachhinein als "kein Spam" klassifiziert
#haette.

my $delete_spam_after = $config{'delete_spam_after'};
if ($delete_spam_after)
{
  my $dataref = $dbi->select_old_postings($delete_spam_after, undef, 'spam');
  while (my $ref = $dataref->fetchrow_arrayref) {
    my ($id,$posting) = @{$ref};
    #Fuettere sie an Spamassassin als Spam
    MOD::Spamfilter::spamlearn($posting,1);
    #Loesche das Posting
    $dbi->delete_posting($id);
  }
}

#Zeige Postings an, die aelter als x Tage sind
my $delete_posting_after = $config{'delete_posting_after'};
if ($delete_posting_after)
{
  my $dataref = $dbi->select_old_postings($delete_posting_after, undef, undef);
  while (my $ref = $dataref->fetchrow_arrayref) {
    my ($id,$posting) = @{$ref};
    #Loesche sie aus der Datenbank
    $dbi->delete_posting($id);
  }
}

my $delete_error_after = $config{'delete_error_after'};
if ($delete_error_after)
{
  $dbi->delete_old_errors($delete_error_after, undef);
}

# End of file
