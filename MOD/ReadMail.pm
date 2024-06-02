######################################################################
#
# $Id: ReadMail.pm 293 2011-06-21 16:01:33Z alba $
#
# Copyright 2009-2011 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
package MOD::ReadMail;

use strict;
use warnings;
use Carp qw( confess );
use News::Article();
use Mail::SpamAssassin();
use MOD::Spamfilter();
use MOD::DBIUtils();

######################################################################
sub new()
######################################################################
{
  my ( $class, $configref ) = @_;
  my $self = {};

  $self->{'config'} = $configref || confess;
  $self->{'spamutil'} = MOD::Spamfilter->new($configref) || confess;
  $self->{'db'} = MOD::DBIUtils->new($configref) || confess;

  bless $self, $class;
  return $self;
}

######################################################################
sub run_spamassassin($$)
{
  my ( $self, $article ) = @_;

  my $spamutil = $self->{'spamutil'} || confess 'No "spamutil" in $self';

  # Temporarily redirect STDOUT and STDERR to /dev/null to ignore
  # diagnostics printed by Spamassassin.
  # Note: SAVE_STDOUT and SAVE_STDERR must be handles.
  # ">&$savestdout" does not work, i.e. it will not restore stdout.

  open(SAVE_STDOUT, ">&STDOUT") or warn "Failed to dup STDOUT: $!";
  open(SAVE_STDERR, ">&STDERR") or warn "Failed to dup STDOUT: $!";
  open(STDOUT, '/dev/null') or warn $!;
  open(STDERR, '/dev/null') or warn $!;
  my $score = $spamutil->spamfilter_spamassassin($article);
  open(STDOUT, ">&SAVE_STDOUT") or warn $!;
  open(STDERR, ">&SAVE_STDERR") or warn $!;
  close SAVE_STDOUT;
  close SAVE_STDERR;

  return $score;
}

######################################################################
sub add_article($$;$)
######################################################################
{
  my ( $self, $article, $status ) = @_;

  # broken spam postings
  return 0 if ($article->bytes() <= 2);

  my $config = $self->{'config'} || confess 'No "config" in $self';
  my $db = $self->{'db'} || confess 'No "db" in $self';
  my $spamutil = $self->{'spamutil'} || confess 'No "spamutil" in $self';

  if (!defined($article->header('Newsgroups')))
  {
    my $group = $config->{'moderated_group'} || confess 'No "moderated_group" in config.';
    $article->set_headers('Newsgroups', $group);
  }

  if ($config->{'followup_to'} && !$article->header('Followup-To'))
  {
    $article->set_headers('Followup-To', $config->{'followup_to'});
  }

  my $score = 0;
  if (!$status)
  {
    if ($spamutil->blacklist($article))
    {
      $score = 100;
      $db->enter_table($article, 'spam', $score);
      return 0;
    }

    if ($config->{'spamassassin'})
    {
      $score += $self->run_spamassassin($article);
    }

    if ($config->{'subjectcheck'} and
	$db->check_subject($article->header('subject')))
    {
      my $subjectscore = $config->{'subjectscore'};
      $article->add_headers('X-Subject-Test', $subjectscore);
      $score += $subjectscore;
    }

    if ($config->{'attachmentcheck'})
    {
      $score += $spamutil->spamfilter_attachment($article);
    }

    if ($config->{'langcheck'})
    {
      $score += $spamutil->spamfilter_language($article);
    }

    $status = 'spam' if ($score >= 5);
  }

  $status = 'pending' unless($status);
  my $rc = $db->enter_table($article, $status, $score);

  return $rc == 1;
}

######################################################################
1;
######################################################################
