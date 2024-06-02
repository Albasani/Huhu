#!/usr/bin/perl -w
######################################################################
#
# $Id: mailget.pl 148 2009-10-13 15:02:22Z alba $
#
# Copyright 2007 - 2009 Roman Racine
# Copyright 2009 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
#
# Reads the mail from the moderator account checks it against
# a spamfilter and either puts it into the "to_moderate" table
# into the "spam" table or discards the mail completly.
#
######################################################################
use strict;
use warnings;
use Net::POP3;

use News::Article;
use MOD::Utils;
use MOD::DBIUtils;
use MOD::Spamfilter;

sub process($);
sub enter_table($);
sub enter_spam_table($);

my %config = MOD::Utils::read_private_config($ARGV[0]);
my $spamutil = MOD::Spamfilter->new(\%config);

my $pop = Net::POP3->new($config{'mod_pop_server'}) or die $!;
if ($pop->login($config{'mod_pop_username'}, $config{'mod_pop_pass'}) > 0) {
  my $msgnums = $pop->list;
  foreach my $msgnum (keys %{$msgnums}) {
    my $article = News::Article->new($pop->get($msgnum));
    if (defined($article)) { 
      eval {
        process($article);
      }; if ($@) {
        print $@,"\n";
      }
    }
    $pop->delete($msgnum);
  }
}
$pop->quit;


sub process($) {
  my $article = shift;
  my $dbi = MOD::DBIUtils->new(\%config);
   # broken spam postings
   return if ($article->bytes() <= 2);
  if (!defined($article->header('Newsgroups'))) {
      $article->set_headers('Newsgroups',$config{'moderated_group'});
  }
  my $score = 0;
  if ($spamutil->blacklist($article)) {
#    $score = 100;
#    $dbi->enter_table($article,'spam',$score);
    return;
  }
  if ($config{'spamassassin'}) {
      open(my $savestdout,">&STDOUT") or warn "Failed to dup STDOUT: $!";
      open(my $savestderr,">&STDERR") or warn "Failed to dup STDOUT: $!";
      open(STDOUT,'/dev/null') or warn $!;
      open(STDERR,'/dev/null') or warn $!;
      $score += $spamutil->spamfilter_spamassassin($article);
      open(STDOUT,">&$savestdout") or warn $!;
      open(STDERR,">&$savestderr") or warn $!;
      
  }

  if ($config{'subjectcheck'} and
      $dbi->check_subject($article->header('subject'))) {
      $article->add_headers('X-Subject-Test',  
			    $config{'subjectscore'});
      $score +=  $config{'subjectscore'};
  }

  if ($config{'attachmentcheck'}) {
      $score += $spamutil->spamfilter_attachment($article);
  }

  if ($config{'langcheck'}) {
      $score += $spamutil->spamfilter_language($article);
  }

  if ($score < 5) {
    $dbi->enter_table($article,'pending',$score);
  } else  {
    $dbi->enter_table($article,'spam',$score);
  } 
}
