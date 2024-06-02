######################################################################
#
# $Id: Spamfilter.pm 147 2009-10-13 14:46:07Z alba $
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
# this is a spamfilter which checks incoming mails and marks them
# as probable Spam.
#
# Heuristics are added as needed.
#
# The main function "spamfilter" returns 
# -1 -> discard (post do de.admin.news.announce)
#  0-5 -> no spam, 
#  >5 -> spam
#
######################################################################
package MOD::Spamfilter;

use strict;
use warnings;
use News::Article;
use Mail::SpamAssassin;
use Text::Language::Guess;

$MOD::Spamfilter::VERSION = 0.02;

sub spamfilter;
sub blacklist;
sub spamlearn;
sub new($);
1;

sub new($) {
  my (undef,$configref) = @_;
  my $self = {};
  $self->{'config'} = $configref;
  bless $self;
  return $self;
}    


sub spamfilter_attachment {
     my ($self,$article) = @_;
     my $score = 0;
     if (defined($article->header('Content-Type')) and  $article->header('Content-Type') =~
	 /^multipart\/(?:mixed|alternative);.+boundary="(.+?)"$/s) {
	 my @parts = split($1,(join "\n",$article->body()));
	 for my $part (@parts) {
	     if ($part =~ /^\r?\n?Content-Type: (image|video|audio|application|text\/html)/) {
		 $score = $self->{'config'}->{'attachmentscore'};
		 last;
	     }
	 }
     }
     $article->add_headers('X-Attachment-Test',$score);
     return $score;
 }


sub spamfilter_language {
    my ($self,$article) = @_;
    my $guesser = Text::Language::Guess->new(languages => ['en',$self->{'config'}->{'lang'}]);
    my @messagebody = $article->body();
    my $score = 0;
    my $lang = $guesser->language_guess_string(join "\n",@messagebody);
    if (!defined($lang) or $lang ne $self->{'config'}->{'lang'}) {
	$score = $self->{'config'}->{'langscore'};
    }
    $article->add_headers('X-Lang-Test',$score);
    return $score;
}
    
sub spamfilter_spamassassin {
  my ($self,$article) = @_;
  # use spamassassin
  my $spamtest = Mail::SpamAssassin->new();
  my @messageheader = $article->headers();
  my @messagebody = $article->body();
  my $header = join "\n",@messageheader;
  my $body = join "\n",@messagebody;
  my $status = $spamtest->check_message_text($header . $body);
  my $score = $status->get_score();
  $article->add_headers('X-Spamassassin-Test',$score);
  return $score;
}

sub blacklist {
   my ($self,$article) = @_;
   return 1 if ($article->header('Newsgroups') =~ /de.admin.news.announce/);
   return 1 if (defined($article->header('Newsgroups')) and 
      $article->header('Newsgroups') !~ /$self->{'config'}->{'moderated_group'}/);
   return 1 if (!defined($article->header('From')));
   return 1 if (length($article->header('From')) < 2);
   return 1 if ($article->bytes() > 100*1024);
   # kaputte Postings
   for my $headerline (qw(From Reply-To Subject Message-ID)) {
       if (defined ($article->header($headerline)) and
           length($article->header($headerline)) > 1019) {
           return 1;
        }
    }
   if (defined $self->{'config'}->{'blacklistfile'}) {
     my $header = join "\n",$article->headers();
     open(my $blacklistfile, $self->{'config'}->{'blacklistfile'}) or die $!;
     while (<$blacklistfile>) {
       chomp;
       next if (length($_) <= 2);
       if ($header =~ /$_/s) {
         close $blacklistfile;
         return 1;
       }
     }
     close $blacklistfile;
   }
   return 0;
}

sub spamlearn {
  my ($input,$isspam) = @_;
  return;
#  my $message = Mail::SpamAssassin::Message->new({'message' => $input});
#  my $spamtest = new Mail::SpamAssassin ({
#    'rules_filename'      => '/etc/spamassassin.rules',
#     'userprefs_filename'  => $ENV{'HOME'}. '/.spamassassin/user_prefs'
#   });
#  my $mail = $spamtest->parse($message);
#  my $status = $spamtest->learn($mail,undef,$isspam,0);
#  $status->finish();                                                                              
  
#  my $spamobj = Mail::SpamAssassin->new();
#  print defined $spamobj,"\n";
#  $spamobj->learn($message,undef,$isspam,0);
}
