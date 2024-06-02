######################################################################
#
# $Id: DBIUtilsPublic.pm 267 2010-05-27 19:46:57Z alba $
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
package MOD::DBIUtilsPublic;

use warnings;
use strict;
use DBI;
use News::Article;
use Carp qw(confess);
use Time::Local;

sub display_single;
sub set_status;
sub set_status_by_moderator;
sub displayrange;
sub get_working_by_id;
sub get_reason;
sub set_rejected;
sub get_statistics;

# 'spam' can be put back to 'pending' queue
# 'moderated' tells poster.pl to send the message via NNTP (there is
#             no safe way to undo this)
# 'rejected' means that a mail was sent the poster - cannot be undone
# 'deleted' can be put back to 'pending' queue
# 'posted' means that message was sent to server - cannot be undone

use constant NOT_FINAL =>
  "status <> 'rejected' AND status <> 'posted' AND status <> 'sending'";

######################################################################
# Constructor, open a new connection to the database
######################################################################
sub new($$)
######################################################################
{
  my ($class,$configref) = @_;
  my $self = {};
  $self->{'config'} = $configref;
  $self->{'dsn'} = "DBI:mysql:database=$self->{'config'}->{'mysql_db'};host=$self->{'config'}->{'mysql_host'};port=$self->{'config'}->{'mysql_port'}";
  $self->{'dbh'} = DBI->connect($self->{'dsn'},$self->{'config'}->{'mysql_username'},$self->{'config'}->{'mysql_password'},
			 { RaiseError => 1}) 
    or die($DBI::errstr);
 
  bless $self,$class;
  return $self;
}


##Die nachfolgenden Methoden sind fuer den Gebrauch im Webinterface bestimmt, alle Methoden, die den Zustand der DB
##aendern, muessen idempotent sein!

######################################################################
# Update the Status of a posting
######################################################################
sub set_status($$$$)
######################################################################
{
  my ($self, $id, $newstatus, $prevstatus) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  my $query =
    "UPDATE $table" .
    "\nSET status=(?)" .
    "\nWHERE id=(?)";
  if ($prevstatus)
  {
    $query .= "\nAND (\n  status = '";
    $query .= join("'\n  OR status = '", @$prevstatus);
    $query .= "'\n)";
  }
  else
  {
    $query .= "\nAND " . NOT_FINAL;
  }

  my $stmt = $self->{'dbh'}->prepare($query);
  return $stmt->execute($newstatus, $id);
}

######################################################################
# Update the Status of a posting
######################################################################
sub set_status_by_moderator()
######################################################################
{
  my ($self, $newstatus, $id, $moderator) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  $self->{'dbh'}->do(
    "UPDATE $table" .
    "\nSET status=(?), Moderator=(?), Moddatum=NOW()" .
    "\nWHERE id=(?)" .
    "\nAND " . NOT_FINAL,
    undef, $newstatus, $moderator, $id
  );
}

######################################################################
sub set_rejected($$$$$)
######################################################################
{
  my ($self, $newstatus, $article_id, $moderator, $reply) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  $self->set_status_by_moderator($newstatus, $article_id, $moderator);
  
  my $query = sprintf(
    "INSERT INTO %s_reply\n" .
    "(article_id, reply_date, reply_message)\n" .
    "VALUES (?, NOW(), ?)\n" .
    "ON DUPLICATE KEY UPDATE\n" .
    "  reply_date = NOW(),\n" .
    "  reply_message=(?)",
    $table
  );
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute($article_id, $reply, $reply);
}

######################################################################
sub set_reply($$$)
######################################################################
{
  my ($self, $article_id, $reply) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  
  my $query = sprintf(
    "INSERT INTO %s_reply\n" .
    "(article_id, reply_date, reply_message)\n" .
    "VALUES (?, NOW(), ?)\n" .
    "ON DUPLICATE KEY UPDATE\n" .
    "  reply_date = NOW(),\n" .
    "  reply_message=(?)",
    $table
  );
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute($article_id, $reply, $reply);
}

######################################################################
# Display a range out of a table
######################################################################
sub displayrange($$$$$)
######################################################################
{
  my ($self,$status,$start,$number_of_results,$overviewref) = @_;
  $start = 0 if ($start !~ /^\d+$/);
  $number_of_results = 1 if ($number_of_results !~ /^\d+$/);

  my $table = $self->{'config'}->{'mysql_table'}
  || confess 'No "mysql_table" in config';

  my $query = sprintf(
    "SELECT %s" .
    "\nFROM %s" . 
    "\nWHERE status=(?)" .
    "\nORDER BY ID DESC" .
    "\nLIMIT %d,%d",
    join(',', @$overviewref),
    $table,
    $start, $number_of_results
  );

  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute($status);
  return $stmt;
}

######################################################################
# display a single entry of a table
######################################################################
sub display_single($$$)
######################################################################
{
  my ($self,$status,$id) = @_;

  my $table = $self->{'config'}->{'mysql_table'} || confess;

  my $query = 
    "SELECT CONCAT(header, \"\\n\\n\", body)," .
    "\n  Status," .
    "\n  Spamcount," .
    "\n  Moderator," .
    "\n  Moddatum AS 'Decision Date'," .
    "\n  Flag" .
    "\nFROM $table" .
    "\nWHERE id=(?)";
  my @param = ( $id );

  if ($status)
  {
    $query .= "\nAND Status=(?)";
    push @param, $status;
  }

  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute(@param);
  return $stmt;
}

######################################################################
sub set_status_posted($$$)
######################################################################
{
  my ($self,$id,$user) = @_;
  return $self->set_status_by_moderator('moderated', $id, $user);
}

######################################################################
sub get_working_by_id($$)
######################################################################
{
  my ($self,$id) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $query = $self->{'dbh'}->prepare(
    "SELECT" .
    "\n  CONCAT(header,\"\\n\\n\",body) AS Posting," .
    "\n  if (length(replyto) > 1,replyto,sender) AS Adresse" .
    "\nFROM $table" .
    "\nWHERE ID=(?)" .
    "\nAND " . NOT_FINAL
  );  
  $query->execute($id);
  return $query;
}

######################################################################
sub get_reason($$)
######################################################################
{
  my ($self,$id) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  my $query = $self->{'dbh'}->prepare(
    "SELECT reply_message" .
    "\nFROM ${table}, ${table}_reply" .
    "\nWHERE ${table}.id = ${table}_reply.article_id" .
    "\nAND article_id=(?)" .
    "\nAND (status='rejected' OR status='deleted')
  ");
  $query->execute($id);
  return $query;
}

######################################################################
sub display_errors($$$$$)
######################################################################
{
  my ($self,$status,$start,$number_of_results,$overviewref) = @_;
  $start = 0 if ($start !~ /^\d+$/);
  $number_of_results = 1 if ($number_of_results !~ /^\d+$/);

  my $table = $self->{'config'}->{'mysql_table'} || confess;

  my $query = sprintf(
    "SELECT %s" .
    "\nFROM %s_error_view" .
    "\nORDER BY error_date DESC" .
    "\nLIMIT %d, %d",
    join(',', @$overviewref),
    $table,
    $start, $number_of_results
  );
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute();
  return $stmt;
}

######################################################################
sub get_errormessage($$)
######################################################################
{
  my ($self,$id) = @_;

  my $table = $self->{'config'}->{'mysql_table'} || confess;

  my $query = sprintf(
    "SELECT error_message" .
    "\nFROM %s_error" .
    "\nWHERE error_id=(?)",
    $table
  );
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute($id);
  return $stmt;
}

######################################################################
sub invert_flag($$)
######################################################################
{
  my ($self,$id) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  $self->{'dbh'}->do(
    "UPDATE $table" .
    "\nSET flag = !flag" .
    "\nWHERE ID=(?)" .
    "\nAND " . NOT_FINAL,
    undef, $id
  );
}

######################################################################
sub calc_item_stats($$)
######################################################################
{
  my ($r_result, $r_items) = @_;

  my @items = sort { $a <=> $b }( @$r_items );
  return undef unless($#items >= 0);

  my $sum = 0;
  for my $i( @items ) { $sum += $i; }

  my $nr_items = 1 + $#items;
  my $pivot = int($nr_items / 2);
  my $median = $items[$pivot];
  if (($nr_items % 2) == 0)
  {
    $median = ( $median + $items[$pivot - 1] ) / 2;
  }

  $r_result->{'count'} = $nr_items;
  $r_result->{'sum'} = $sum;
  $r_result->{'avg'} = $sum / $nr_items;
  $r_result->{'median'} = $median;
  $r_result->{'min'} = $items[0];
  $r_result->{'max'} = $items[ $#items ];

  return $r_items;
}

######################################################################
sub get_reaction_time($;$$$)
######################################################################
{
  my ( $self, $from, $to, $status ) = @_;

  # Warning: Plain "Moddatum - Datum" returns strange values when
  # crossing day boundaries. Using unix_timestamp instead.

  my $query =
    "select unix_timestamp(Datum), timestampdiff(SECOND, Datum, Moddatum)" .
    "\nfrom " . $self->{'config'}->{'mysql_table'} .
    "\nwhere datum is not null" .
    "\nand Moddatum is not null" .
    "\nand Datum is not null";

  if ($from)
    { $query .= "\nand datum >= from_unixtime($from)"; }
  if ($to)
    { $query .= "\nand datum < from_unixtime($to)"; }
  if ($status)
    { $query .= "\nand Status = '$status'"; }

  my $sth = $self->{'dbh'}->prepare($query);
  $sth->execute();

  my %result;
  while(my $row = $sth->fetchrow_arrayref )
  {
    my $datum = 0 + $row->[0];
    my $reaction_time = 0 + $row->[1];
    my ($sec, $minute, $hour, $mday, $month, $year, $wday, $yday, $isdst) =
    localtime($datum);

    my $y = sprintf("%04d", $year + 1900);
    my $m = sprintf("%02d", $month + 1);
    my $d = sprintf("%02d", $mday);

    my $items = $result{$y}->{$m}->{$d}->{'items'};
    if (defined( $items ))
    {
      push @$items, $reaction_time;
    }
    else
    {
      $result{$y}->{$m}->{$d}->{'items'} = [ $reaction_time ];
    }
  }

  # we are going to modify the hash so we need robust iteration
  my @year = keys(%result);
  my @all_items;

  for my $year(@year)
  {
    my $r_month = $result{$year};
    my @month = keys(%$r_month);
    my @year_items;

    for my $month(@month)
    {
      my $r_mday = $r_month->{$month};
      my @mday = keys(%$r_mday);
      my @month_items;

      for my $mday(@mday)
      {
	my $r = $r_mday->{$mday};
        my $r_items = $r->{'items'};
	push @month_items, @$r_items;
	calc_item_stats($r, $r_items);
	# delete $r->{'items'};
      }

      push @year_items, @month_items;
      calc_item_stats($r_mday->{'total'} = {}, \@month_items);
    }
    push @all_items, @year_items;
    calc_item_stats($r_month->{'total'} = {}, \@year_items);
  }
  calc_item_stats($result{'total'} = {}, \@all_items);

  return \%result;
}

######################################################################
sub get_statistics($)
######################################################################
{
  my ($self) = @_;
  my $dbh = $self->{'dbh'}
  || confess 'No "dbh" in self';
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  #
  # Warning: The combination of union and selectall_arrayref does not
  # like null values. They are just ommitted from the result.
  #
  my $arrayref = $dbh->selectall_arrayref(
    "select unix_timestamp(min(datum)) from $table" .
    "\nunion" .
    "\nselect unix_timestamp(max(datum)) from $table"
  );

  if (!$arrayref) { return undef; }
  if (!$arrayref->[1]) { return undef; }
  if (!$arrayref->[0]) { return undef; }

  # add 1 because query is (datum >= min and datum < max)
  my $to = 1 + $arrayref->[1]->[0];
  my $from = $arrayref->[0]->[0];
  undef $arrayref;

  my $result = {
    'all' => $self->get_reaction_time($from, $to)
  };
  for my $status(
    'pending',
    'moderated',
    'spam',
    'rejected',
    'deleted',
    'posted',
    'sending')
  {
    $result->{$status} = $self->get_reaction_time($from, $to, $status);
  }

  return $result;
}

######################################################################
1;
######################################################################
