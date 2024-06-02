#####################################################################
#
# $Id: de.pm 298 2011-09-04 11:11:33Z root $
#
# Copyright 2009 Roman Racine
# Copyright 2009-2011 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
#
# This file is encoded in iso-8859-1
#
######################################################################
package MOD::lang::de;

use warnings;
use strict;

######################################################################
use constant TRANS =>
######################################################################
{
  '_ALREADY_HANDLED' => 'Dieser Eintrag wurde bereits von einem anderen Moderator bearbeitet.',
  'Approved Messages' => 'Zugelassene Postings',
  'Approved' => 'Zugelassen',
  'Approve' => 'Posten',
  '_ARRIVAL_NOTICE_BODY' => "In der Moderationsqueue sind noch eines oder mehrere Postings\nvon dir unbearbeitet. Dies ist eine automatische Nachricht.\n",
  '_ARRIVAL_NOTICE_SUBJECT' => '[%s] Eingangsbestaetigung',
  'article_sender' => 'Sender',
  'article_status' => 'Status',
  'article_subject' => 'Betreff',
  'Available Actions' => 'M�gliche Aktionen',
  'Back' => 'Zur�ck',
  'Brief Headers' => 'Header verbergen',
  _CROSSPOSTED => 'Vorsicht, dieses Posting ist in mehr als zwei NGs crossgepostet!',
  'Date' => 'Datum',
  'Decision Date' => 'Entscheidungsdatum',
  'Delete and save reason' => 'L�schen und Begr�ndung speichern',
  'Delete and save reason' => 'L�schen und Begr�ndung speichern',
  'Deleted' => 'Gel�scht',
  'Deleted Posts' => 'Gel�schte Postings',
  'Delete' => 'L�schen',
  'Delete Post' => 'Posting l�schen',
  'error_count' => 'Fehleranzahl',
  'error_date' => 'Datum',
  'Error' => 'Fehler',
  _ERROR_GONE => 'Die Fehlermeldung liegt nicht mehr vor, der Fehler ist behoben.',
  _ERROR_INVALID_ADDRESS => 'Ung�ltige Adresse, Versand eines Mails nicht m�glich.',
  'error_message' => 'Fehlermeldung', 
  'Error Messages' => 'Fehlermeldungen',
  '_EXPLAIN_REASON' => 'Hier kann ein Grund f�r die L�schung des Artikels angegeben werden. Dieser Text ist nur f�r die �brigen Moderationsmitglieder sichtbar.',
  'Incoming Date' => 'Eingangsdatum',
  'Messages' => 'Postings',
  'Next page' => 'Vorw�rts bl�ttern',
  'No matching records available.' => 'Kein passender Datensatz vorhanden.',
  'No reason stored in database!' => 'Keine Begr�ndung in der Datenbank vorhanden!',
  'No Spam' => 'Kein Spam',
  'No subject' => 'Kein Betreff',
  'Overview of Approved Posts' => '�berblick �ber die zugelassenen Postings',
  'Pending' => 'Offen',
  'Pending Posts' => 'Offene Moderationsentscheidungen',
  'Posted' => 'Gesendet',
  'Posted Messages' => 'Gesendete Postings',
  'Previous page' => 'Zur�ck bl�ttern',
  'Put back in queue' => 'In Moderationsqueue zur�ck',
  'Reason' => 'Begr�ndung',
  'Rejected' => 'Abgewiesen',
  'Rejected Posts' => 'Zur�ckgewiesene Postings',
  'Reject Post' => 'Posting zur�ckweisen',
  'Reject' => 'Zur�ckweisen',
  'Reply' => 'Antwort',
  'Selected Article' => 'Gew�hlter Artikel',
  'Sender' => 'Absender',
  'Send Mail' => 'Mail verschicken',
  'Show' => 'Anzeigen',
  'Show Error Message' => 'Fehlermeldung anzeigen',
  'Show Post' => 'Posting anzeigen',
  'Show Reply' => 'Antwort anzeigen',
  'Spam Folder' => 'Spamordner',
  'Subject' => 'Betreff',
  '_SUBTITLE_APPROVED' => 'Zugelassene aber noch nicht gesendete Postings.',
  '_SUBTITLE_DELETED' => 'Ignorierte Postings.',
  '_SUBTITLE_ERROR' => 'Zugelassene Postings die nicht gesendet werden konnten. Wird automatisch wiederholt.',
  '_SUBTITLE_PENDING' => 'Postings die auf eine Entscheidung warten.',
  '_SUBTITLE_POSTED' => 'Zugelassene Postings die zum Newsserver gesendet wurden.',
  '_SUBTITLE_REJECTED' => 'Abgelehnte Postings, bei denen dem Sender eine Begr�ndung geschickt wurde.',
  '_SUBTITLE_SPAM' => 'Postings die vom Spamfilter oder einem Moderator als Spam kategorisiert wurden.',
  '%s wrote:' => '%s schrieb:',
  'Your post regarding' => 'Dein Posting zum Thema',
};
                                               
sub get_translator($)
{
  return sub {
    my $result = TRANS->{$_[0]};
    return $result ? $result : $_[0];
  };
}

1;
