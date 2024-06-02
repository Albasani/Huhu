######################################################################
#
# $Id: Handler.pm 261 2010-02-21 16:10:09Z root $
#
# Copyright 2007-2009 Roman Racine
# Copyright 2009-2010 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
package MOD::Handler;

use strict;
use warnings;
use Carp qw( confess );
use CGI();
use MOD::Utils;
use MOD::Displaylib;

######################################################################
sub new($$)
######################################################################
{
  my ($class, $filename) = @_;
  my $self = {};

  my %config = MOD::Utils::read_public_config($filename);
  $self->{'config'} = \%config;

  $self->{'d'} = MOD::Displaylib->new(\%config, 1);
  $self->{'q'} = $self->{'d'}->{'q'} || confess;

  bless $self, $class;
  return $self;
}

######################################################################
sub run($)
######################################################################
{
  my $self = shift || confess;

  my $query = $ENV{'QUERY_STRING'};
  $query =~ s/keywords=//;
  my ($cmd, $start, $id) = split(',',$query);
  if (!defined($start) || $start !~ /^\d+$/) {
    $start = 0;
  } 
  if (!$cmd) { $cmd = 'pending'; }

  my $q = $self->{'q'} || confess 'No "q" in $self';

  $id = $q->param('id');
  if (!defined($id) || $id !~ /^\d+$/) {
    $id = 0;
  }

  if ($q->param('action.Show') ||
      $q->param('action.Header') ||
      $q->param('action.Brief Headers') ||
      $q->param('action.Show Post'))
  {
    return $self->display_single($cmd, $start, $id);
  }
  if (
    $q->param('action.Spam') ||
    $q->param('action.No Spam') ||
    $q->param('action.Put back in queue'))
  {
    $self->{'d'}->set_status_by_moderator(
      $q->param('action.Spam') ? 'spam' : 'pending',
      $id
    );
    return $self->display_overview($cmd, $start, $id);
  }
  if ($q->param('action.Flag')) {
    $self->{'d'}->set_flag($id);
    return $self->display_overview($cmd, $start, $id);
  }
  if ($q->param('action.Reject')) {
    return $self->reject('answer', $id);
  }
  if ($q->param('action.Approve')) {
    $self->{'d'}->post($id);
    return $self->display_overview($cmd, $start, $id);
  }
  if ($q->param('action.Send Mail')) {
    $self->{'d'}->send_mail($id) &&
    return $self->display_overview($cmd, $start, $id);
  }
  if ($q->param('action.Show Reply') ||
      $q->param('action.Reason'))
  {
    return $self->display_answer($cmd, $start, $id);
  }
  if ($q->param('action.Delete')) {
    return $self->reject('noanswer', $id);
  }
  if ($q->param('action.Delete and save reason')) {
    $self->{'d'}->delete_posting($id);
    return $self->display_overview($cmd, $start, $id);
  }
  if ($q->param('action.Show Error Message')) {
    return $self->display_errormessage($q->param('error_id'));
  }
  if ($cmd eq 'config') {
    return $self->{'d'}->display_config();
  }
  
  return $self->display_overview($cmd, $start, $id);
}

use constant SQL_TIME_FORMAT => '"%d.%m.%Y, %H:%i:%s"';
use constant DEFAULT_COLUMNS => [
  'Moderator',
  'Sender',
  'Subject',
  'Date_Format(Datum, ' . SQL_TIME_FORMAT . ") AS 'Incoming Date'",
  'Date_Format(Moddatum, ' . SQL_TIME_FORMAT . ") AS 'Decision Date'"
];
use constant PENDING_COLUMNS => [
  'Sender',
  'Subject',
  'DATE_Format(Datum, ' . SQL_TIME_FORMAT . ') Date',
  'Spamcount'
];
use constant OVERVIEW => {
  'spam' => {
    -decisionref => [ 'Show', 'No Spam', 'Flag' ],
    -overviewref => [
      'Moderator',
      'Sender',
      'Subject',
      'DATE_Format(Datum, ' . SQL_TIME_FORMAT . ') Date',
      'Spamcount'
    ],
    -title => 'Spam Folder',
    -subtitle => '_SUBTITLE_SPAM',
  },
  'pending' => {
    -decisionref => [ 'Show', 'Spam', 'Flag' ],
    -overviewref => PENDING_COLUMNS,
    -title => 'Pending Posts',
    -subtitle => '_SUBTITLE_PENDING',
  },
  'rejected' => {
    -title => 'Rejected Posts',
    -subtitle => '_SUBTITLE_REJECTED',
  },
  'errors' => {
    -decisionref => [ 'Show Post', 'Show Error Message' ],
    -overviewref => [
       'error_date',
       'article_sender',
       'article_subject',
       'article_status',
       'error_count',
       'LEFT(error_message, INSTR(error_message, "\n")) AS error_message',
    ],
    -title => 'Error Messages',
    -subtitle => '_SUBTITLE_ERROR',
    -hiddencolumns => [ 'error_id' ],
  },
  'moderated' => {
    -title => 'Approved Messages',
    -subtitle => '_SUBTITLE_APPROVED',
  },
  'posted' => {
    -title => 'Posted Messages',
    -subtitle => '_SUBTITLE_POSTED',
  },
  'deleted' => {
    -title => 'Deleted Posts',
    -subtitle => '_SUBTITLE_DELETED',
  },
};


sub display_overview {
  my ($self, $cmd, $start, $id) = @_;
  my @decisions;
  my @overviewdata;
  my ($status, $title);

  my $ovref = OVERVIEW->{$cmd} || confess 'Illegal $cmd';
  my %params = %{$ovref}; # create copy of the hash

  if (!exists( $params{'-cmd'} )) {
    $params{'-cmd'} = $cmd;
  }
  if (!exists( $params{'-status'} )) {
    $params{'-status'} = $cmd;
  }
  if (!exists( $params{'-decisionref'} )) {
    $params{'-decisionref'} = [ 'Show' ];
  }
  if (!exists( $params{'-overviewref'} )) {
    $params{'-overviewref'} = DEFAULT_COLUMNS;
  }
  if (!exists( $params{'-no_of_elements'} )) {
    my $config = $self->{'config'} || confess 'No "config" in $self';
    my $c = $config->{'display_per_page'} || confess 'No "display_per_page" in $config';
    $params{'-no_of_elements'} = $c;
  }

  $params{'-start'} = $start;
  $params{'-startrange'} = $id;

  $self->{'d'}->display_table(%params);
}

sub reject {
  my ($self,$behaviour,$id) = @_;
  my $title = ($behaviour eq 'noanswer')
  ? 'Delete Post'
  : 'Reject Post';
  $self->{'d'}->generate_answer($id,$behaviour,$title);
  return;
}

sub display_answer {
  my ($self,$cmd,$start,$id) = @_;
  my $title = ($cmd eq 'rejected') ? 'Reply' : 'Reason';
  my @decisions = ('Show Post');
  $self->{'d'}->display_reason($id,\@decisions,$title);
  return;
}

sub display_errormessage {
  my ($self,$id) = @_;
  $self->{'d'}->display_errormessage($id, 'Error Message');
  return;
}

use constant HEADERS => [
  'From',
  'Reply-To',
  'Subject',
  'Message-ID',
  'Date',
  'Newsgroups',
  'Followup-To',
];

use constant SINGLE => {
  'pending' => [ 'Approve', 'Reject', 'Flag', 'Spam', 'Delete' ],
  'spam' => [ 'No Spam', 'Approve', 'Flag', 'Reject', 'Delete' ],
  'errors' => [ 'Reject', 'Flag', 'Spam', 'Delete' ],
  'moderated' => [ 'Put back in queue' ],
  'posted' => [],
  'rejected' => [ 'Show Reply' ],
  'deleted' => [ 'Put back in queue', 'Reason' ],
};

sub display_single {
  my ($self, $cmd, $start, $id) = @_;

  my $q = $self->{'q'} || confess 'No "q" in $self';
  my $decisionref = SINGLE->{$cmd} || confess "Illegal \$cmd ($cmd)";
  my @decisions = @$decisionref;

  my $fullheader = $q->param('action.Header') ? 1 : 0;
  push(@decisions, $fullheader ? 'Brief Headers' : 'Header');

  my %args = (
    -status => $cmd,
    -id => $id,
    -headerref => HEADERS,
    -decisionref => \@decisions,
    -fullheader => $fullheader
  );
  $self->{'d'}->display_article(%args);
  return;
}

######################################################################
1;
######################################################################
