######################################################################
#
# $Id: PublicHandler.pm 159 2009-10-30 11:32:21Z root $
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
package MOD::PublicHandler;

use strict;
use warnings;
use Carp qw(confess);
use CGI();
use MOD::Utils;
use MOD::Displaylib;

=pod

=head1 NAME

MOD::PublicHandler

=head1 DESCRIPTION

This module provides public access to the moderation database. Only things which should
be viewable to the public. Data which should only be accessable or changeable by the
moderators cannot be retrieved, manipulated whith this module. Use MOD::Handler instead.

=head1 REQUIREMENTS

  MOD:*
  CGI
  News::Article

=head1 AUTHOR

Roman Racine <roman.racine@gmx.net>


=head1 VERSION

2007-11-24

=cut

$MOD::PublicHandler::VERSION = 0.04;
my %config;
my $sql_time_format = '"%d.%m.%Y, %H:%i:%s"';
1;

=pod

=head1 new

constructor

  usage:

  my $handler = MOD::PublicHandler->new('/path/to/the/config/file');
  $handler->run();

=cut

sub new {
  my ($class,$filename) = @_;
  my $self = {};
  %config = MOD::Utils::read_public_config($filename);
  $self->{'q'} = new CGI;

# 0 -> get unpriviledged (i.e. non-moderator) access to the displaylib
  $self->{'d'} = MOD::Displaylib->new(\%config,0);
  $self->{'config'} = \%config;
  bless $self, $class;
  return $self;
}

=pod

=head1 run

usage:

  my $handler = MOD::PublicHandler->new('/path/to/the/config/file');
  $handler->run();

This is the main handling routine, this method will get the arguments from the browser,
parse it and handle it, calling the necessary routines.

=cut

sub run {
  my $self = shift;
  my $start;

  my $q = $self->{'q'} || confess 'No "q" in $self';

#get the parameters, check for illegal values
  (undef,$start) = split (',',$ENV{'QUERY_STRING'});
  if (!defined($start) || $start !~ /^\d+$/) {
    $start = 0;
  }

  my $id = $q->param('id');
  $id = 0 unless($id);

#call the handling routines
  if ($q->param('action.Show')) {
    $self->display_single($start,$id);
  } else {
    $self->display_overview($start,$id);
  }
  return;
}


########## The following methods are for internal use only #####################

#method to display an overview over a number of postings using a table format.
sub display_overview {
  my ($self,$start,$id) = @_;
 
  $self->{'d'}->display_table(
    -status => 'posted',
    -start => $start,
    -no_of_elements => $self->{'config'}->{'display_per_page'},
    -overviewref => [
      'Sender',
      'Subject',
      "Date_Format(Datum,$sql_time_format) AS 'Incoming Date'",
      "Date_Format(Moddatum,$sql_time_format) AS 'Decision Date'"
    ],
    -decisionref => [ 'Show' ],
    -title => 'Overview of Approved Posts',
    -cmd => 'bla',
    -startrange => $id
  );
  return;
}

#method to display a single article given by an ID.
sub display_single {
  my ($self,$start,$id) = @_;
  my %args = (
    -status => 'posted',
    -id => $id,
    -headerref => [ 'From', 'Reply-To', 'Subject', 'Date', 'Newsgroups' ],
    -decisionref => [],
    -fullheader => 0,
  );
  $self->{'d'}->display_article(%args);
  return;
}

