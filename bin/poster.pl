#!/usr/bin/perl -w
######################################################################
#
# $Id: poster.pl 303 2011-10-31 13:03:03Z root $
#
# Copyright 2007 - 2009 Roman Racine
# Copyright 2009 - 2011 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################

=pod

=head1 NAME

poster.pl

=head1 DESCRIPTION

Dieses Programm liest die zu postenden Postings aus der
Datenbank aus und postet sie ins Usenet. Sofern dies erfolgreich
ist, setzt es das Bit "posted" in der Datenbank.

Wenn der Versand nicht erfolgreich ist, tut das Programm nichts,
d.h, das Posten wird bei einem spaeteren Aufruf des Programms
einfach nochmals versucht.

Dieses Programm sollte am besten via Cronjob laufen.

Das Programm wird mit
./poster.pl <Pfad zum Configfile> aufgerufen
Dasselbe Programm mit unterschiedlichen Konfigurationsfiles
aufgerufen kann zur Moderation mehrerer Gruppen eingesetzt werden.

=head1 REQUIREMENTS

Net::NNTP

News::Article

MOD::*

=head1 AUTHOR

Roman Racine <roman.racine@gmx.net>

=head1 VERSION

10. Februar 2007

=cut

######################################################################

use strict;
use warnings;
use Carp qw(confess);

use Net::NNTP();
use News::Article;

use MOD::Utils;
use MOD::DBIUtils;

use constant DEBUG => 0;

######################################################################
sub connect_nntp($)
######################################################################
{
  my $r_config = shift || confess;

  my $cfg_nntp_server = $r_config->{'nntp_server'} ||
    die 'No "nntp_server" in configuration file';
  my $nntp = new Net::NNTP($cfg_nntp_server, 'DEBUG' => DEBUG) ||
    die "Can't connect to news server $cfg_nntp_server";

  my $cfg_nntp_user = $r_config->{'nntp_user'} ||
    die 'No "nntp_user" in configuration file';
  my $cfg_nntp_pass = $r_config->{'nntp_pass'} ||
    die 'No "nntp_pass" in configuration file';

  # authinfo does not return a value
  $nntp->authinfo($cfg_nntp_user, $cfg_nntp_pass);

  return $nntp;
}

######################################################################
# MAIN
######################################################################

my %config = MOD::Utils::read_private_config($ARGV[0]);
my $approve_string = $config{'approve_string'} ||
  die 'No "approve_string" in $config';

my $moderated_group = $config{'moderated_group'};
my $pgp_passphrase = $config{'pgp_passphrase'};
my $pgp_keyid = $config{'pgp_keyid'};
my $sign_pgpmoose = ($moderated_group && $pgp_passphrase && $pgp_keyid);

if ($sign_pgpmoose && DEBUG > 1)
{
  print "News::Article::sign_pgpmoose enabled.\n";
}

my Net::NNTP $nntp = connect_nntp(\%config);
my $dbi = MOD::DBIUtils->new(\%config) ||
  die "Can't connect to database";

# Select all posts that have been approved but not posted,
# i.e. all posts in the state 'moderated'.
my $dataref = $dbi->select_unposted();

#Schleife ueber alle selektierten Postings
#Einlesen des Postings, Header anpassen,anschliessend posten
#und das das posted-Bit in der Datenbank setzen.

while (my $ref = $dataref->fetchrow_arrayref)
{
  my ($id,$posting) = @{$ref};
  next unless($dbi->set_status($id, 'sending', [ 'moderated' ]));

# Posting einlesen.
  my $article = News::Article->new(\$posting);
  next if (!defined($article->header('Newsgroups')));

  { # Save original date header
    my $date = $article->header('Date');
    if ($date)
      { $article->set_headers('X-Huhu-Submission-Date', $date); }
  }

  # Drop superfluous headers
  $article->drop_headers(
    'Approved',
    'Date',
    'Delivery-date',
    'Delivered-To',
    'Errors-To',		# Mailman
    'Envelope-to',
    'Injection-Info',		# defined by INN 2.6.x and Schnuerpel 2010
    'Lines',			# defined by INN 2.5.x or older
    'NNTP-Posting-Date',	# defined by INN 2.5.x or older
    'NNTP-Posting-Host',	# defined by INN 2.5.x or older
    'Path',
    'Precedence',		# Mailman
    'Received',
    'Status',
    'Return-Path',
    'To',
    'X-Antivirus',
    'X-Antivirus-Status',
    'X-Attachment-Test',
    'X-Beenthere',		# Mailman
    'X-Complaints-To',		# defined by INN 2.5.x or older
    'X-Lang-Test',
    'X-Mailman-Version',	# Mailman
    'X-MSMail-Priority',	# Outlook
    'X-NNTP-Posting-Host',	# set by Schnuerpel 2009 or older
    'X-Originating-IP',
    'X-Priority',		# Outlook
    'X-Provags-ID',		# GMX/1&1
    'X-Spamassassin-Test',
    'X-Spam-Checker-Version',
    'X-Spam-Level',
    'X-Spam-Report',
    'X-Spam-Score',
    'X-Spam-Status',
    'X-Subject-Test',
    'X-Trace',			# defined by INN 2.5.x or older
    'X-User-ID',		# set by Schnuerpel 2009 or older
    'X-Virus-Scanned',
    'X-Y-Gmx-Trusted',		# GMX/1&1
    'X-Zedat-Hint',		# Uni Berlin/Individual?
  );

#albasani-workaround fuer @invalid
  if ($article->header('From') =~ /\@invalid[> ]/i) {
      my $newfrom = $article->header('From');
      $newfrom =~ s/\@invalid/\@invalid.invalid/i;
      $article->set_headers('From',$newfrom);
  }      
# albasani-workaround fuer leere User-Agent headerzeilen
  if (defined $article->header('User-Agent') and $article->header('User-Agent') !~ /\w/) {
     $article->drop_headers(('User-Agent'));
  }

#Neue Message-ID und Approved-Header erzeugen
 my $mid = defined($article->header('Message-ID')) ? $article->header('Message-ID') :
          '<' . substr (rand() . '-' . time(), 2) . '@' . $config{'mid_fqdn'} . '>';
 $article->set_headers('Message-ID', $mid, 'Approved', $approve_string);

#signieren
  if ($sign_pgpmoose)
  {
    my @msg = $article->sign_pgpmoose($moderated_group, $pgp_passphrase, $pgp_keyid);
    if (@msg)
    {
      print join("\n", 'News::Article::sign_pgpmoose ', @msg); 
    }
  }

  my @articleheaders = $article->header('References');
  eval {
# Workaround fuer Buggy Software, die kaputte References erzeugt
   my @references = $article->header('References');
   if (@references > 1) {
       $article->set_headers('References', join "\n ", @references);
   } 
#posten
  $article->post($nntp) or die $!;
#posted-Bit setzen, aktuelle MID in DB eintragen (wird in Zukunft vielleicht mal von einer Zusatzfunktion benoetigt)
  $dbi->set_posted_status($id,$mid);
 }; 
  # Fehler in Datenbank festhalten, sofern einer aufgetreten ist
  if ($@) {
    $dbi->increase_errorlevel($id, $@);
    $dbi->set_status($id, 'moderated', [ 'sending' ]);
  }
}
