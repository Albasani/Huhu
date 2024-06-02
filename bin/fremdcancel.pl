#!/usr/bin/perl
######################################################################
#
# $Id: fremdcancel.pl 302 2011-09-30 00:09:02Z alba $
#
# Copyright 2007 - 2009 Roman Racine
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
BEGIN { push (@INC, $ENV{'HUHU_DIR'}); }

use strict;
use warnings;
use Net::NNTP;
use News::Article;
use News::Article::Cancel;
use MOD::Utils;

use constant NR_POSTS_TO_EXAMINE => 5;

######################################################################
sub check_pgp($$$)
######################################################################
{
  my $article = shift || die;
  my $moderated_group = shift || die;
  my $pgp_keyid = shift || die;

  my $mid = $article->header('message-id') || die 'No Message-ID';
  my $result =  $article->verify_pgpmoose($moderated_group);

  if (!$result)
  {
    printf "Checking %s, not signed.\n", $mid;
    return undef;
  }
  if ($result ne $pgp_keyid)
  {
    printf "Checking %s, signed with wrong key. Expected '%s', got '%s'.\n",
      $mid, $pgp_keyid, $result;
    return undef;
  }
  printf "Checking %s, ok\n", $mid;
  return 1;
}

######################################################################
# MAIN
######################################################################

my %config = MOD::Utils::read_private_config($ARGV[0]);

my $moderated_group = $config{'moderated_group'};
if (!$moderated_group)
{
  printf "Missing configuration item 'moderated_group'.\n";
  exit(1);
}

my $pgp_keyid = $config{'pgp_keyid'};
if (!$pgp_keyid)
{
  printf "Missing configuration item 'pgp_keyid'.\n";
  exit(1);
}

my $nntp = new Net::NNTP($config{'nntp_server'}) or exit(0);
$nntp->authinfo($config{'nntp_user'},$config{'nntp_pass'}) or exit(0);
my ($articles,$first,$last,undef) = $nntp->group($config{'moderated_group'});

my $start = $last - NR_POSTS_TO_EXAMINE;
if ($start < $first) { $start = $first; }

for my $id ($start .. $last)
{
  my $articletext = $nntp->article($id);
  if (defined($articletext))
  {
    my $article = News::Article::Cancel->new($articletext);
    my $ok = check_pgp($article, $moderated_group, $pgp_keyid);
    if (!$ok)
    {
      next if ($article->header('Newsgroups') =~ /de.admin.news.announce/);
      my $cancel = $article->make_cancel($config{'approve_string'},'moderator','Gecancelt because of fake approval');
      $cancel->set_headers('Approved',$config{'approve_string'});
      $cancel->sign_pgpmoose($config{'moderated_group'},$config{'pgp_passphrase'},$config{'pgp_keyid'});
      $cancel->post($nntp);
    }
  }
}
