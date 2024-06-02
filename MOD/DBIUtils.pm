######################################################################
#
# $Id: DBIUtils.pm 305 2011-12-26 19:51:53Z root $
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
package MOD::DBIUtils;

use warnings;
use strict;
use Carp qw( confess );

use DBI();
use MOD::Utils qw(read_private_config);
use News::Article();
use MOD::DBIUtilsPublic();
use Digest::SHA1();

push @MOD::DBIUtils::ISA,'MOD::DBIUtilsPublic';

######################################################################
sub enter_table($$$$)
######################################################################
{
  my ($self,$article,$status,$spamcount) = @_;
  my %tmphash;
  for my $headerdata (qw(Reply-To Subject Message-ID)) {
     $tmphash{$headerdata} = defined($article->header($headerdata)) ? $article->header($headerdata) : ' ';
  }

  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $body = join("\n", $article->body());

  my @columns = (
    'Sender',
    'ReplyTo',
    'Subject',
    'MessageID',
    'Spamcount',
    'Status',
    'Header',
    'Body',
    'Datum',
    'checksum'
  );
  my @values = (
    $article->header('From'),
    $tmphash{'Reply-To'},
    $tmphash{'Subject'},
    $tmphash{'Message-ID'},
    $spamcount,
    $status,
    join("\n", $article->headers()),
    $body,
  );

  my $value_format = '?,?,?,?,?,?,?,?,NOW(),SHA1(Body)';
  if ($status eq 'moderated')
  {
    push @columns, 'Moddatum';
    $value_format .= ',NOW()';
  }

  my $rc = $self->{'dbh'}->do(
    'INSERT IGNORE INTO ' . $table .
    ' (' . join(',', @columns) . ')' .
    ' VALUES(' . $value_format . ')',
    undef,
    @values
  );
  if ($rc != 1)
  {
    my $msg = 'enter_table failed';
    my $article_id = undef;

    my $age = $self->{'config'}->{'check_duplicates_age'} || 7;
    my $sha1 = Digest::SHA1::sha1_hex($body);
    my $stmt = $self->{'dbh'}->prepare(
      "SELECT id\n" .
      "\nFROM " . $table .
      "\nWHERE checksum=?" .
      "\nAND Datum < DATE_SUB(CURDATE(), INTERVAL ? DAY);"
    );
    $stmt->execute($sha1, $age);
    my $row = $stmt->fetchrow_arrayref;
    if ($row)
    {
      ( $article_id ) = @$row;
      $msg = 'Duplicate received';
    }

    $msg .= "\n*** sha1_hex(\$body) ***\n" . $sha1;
    for(my $i = 0; $i <= $#values; $i++)
    {
      if ($values[$i])
      {
	$msg .= "\n*** " . $columns[$i] . "***\n" . $values[$i];
      }
    }
    $self->increase_errorlevel($article_id, $msg);
  }
  return $rc;
}

######################################################################
sub select_unposted($)
######################################################################
{
  my $self = shift;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $query = $self->{'dbh'}->prepare(
    "SELECT ID, CONCAT(header,\"\\n\\n\",body)\n" .
    "FROM $table\n" .
    "WHERE status='moderated'");
  $query->execute();
  return $query;
}

######################################################################
sub set_posted_status($$$)
######################################################################
{
  my ($self,$id,$mid) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;

  $self->{'dbh'}->do(
    "UPDATE $table\n" .
    "SET status='posted', MessageID=(?)\n" .
    "WHERE ID=(?)\n" .
    "AND (status = 'moderated' OR status = 'sending')",
    undef, $mid, $id
  );
  $self->{'dbh'}->do(
    "DELETE FROM ${table}_error\n" .
    "WHERE article_id=(?)\n",
    undef, $id
  );
  return;
}

######################################################################
sub delete_posting($$)
######################################################################
{
  my ($self,$id) = @_; 
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  $self->{'dbh'}->do(
    "DELETE FROM $table" .
    "\nWHERE ID=(?)" .
    "\nAND status <> 'pending'" .
    "\nAND status <> 'sending'",
    undef, $id
  );
}

######################################################################
sub select_old_postings($$$$)
######################################################################
{
  my ($self,$end,$start,$status) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $query =
    "SELECT ID, CONCAT(header,\"\\n\\n\",body)" .
    "\nFROM $table" .
    "\nWHERE status <> 'pending'" .
    "\nAND Datum < DATE_SUB(CURDATE(), INTERVAL ? DAY)";
  my @values = ( $end );
  if (defined($start)) {
    $query .= "\nAND Datum > DATE_SUB(CURDATE(), INTERVAL ? DAY)";
    push @values, $start;
  }
  if (defined($status)) {
    $query .= "\nAND status=?";
    push @values, $status;
  }
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute(@values);
  return $stmt;
}

######################################################################
sub delete_old_errors($$$$)
######################################################################
{
  my ($self, $end, $start, $status) = @_;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $query =
    "DELETE FROM ${table}_error" .
    "\nWHERE error_date < DATE_SUB(CURDATE(), INTERVAL ? DAY)";
  my @values = ( $end );
  if (defined($start)) {
    $query .= "\nAND error_date > DATE_SUB(CURDATE(), INTERVAL ? DAY)";
    push @values, $start;
  }
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute(@values);
  return $stmt;
}
  
######################################################################
sub select_pending($)
######################################################################
{
  my $self = shift || die;
  my $table = $self->{'config'}->{'mysql_table'} || confess;
  my $query =
    "select DISTINCT(if (length(replyto) > 1,replyto,sender)) AS Adresse" .
    "\nFROM ${table}" .
    "\nwhere status='pending'" .
    "\nAND datum < DATE_SUB(NOW(), INTERVAL ? HOUR)" .
    "\nAND datum > DATE_SUB(NOW(), INTERVAL ? HOUR)";
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute(
    $self->{'config'}->{'min_time_until_autoreply'},
    $self->{'config'}->{'max_time_until_autoreply'}
  );
  return $stmt;
}  

######################################################################
sub increase_errorlevel($$$)
######################################################################
{
  my ($self, $article_id, $reason) = @_;

  my $query = sprintf(
    "INSERT INTO %s_error\n" .
    "(article_id, error_date, error_count, error_message)\n" .
    "VALUES (?, NOW(), 1, ?)\n" . 
    "ON DUPLICATE KEY UPDATE\n" .
    "  error_count = IF(error_count + 1 > 100, 100, error_count + 1),\n" .
    "  error_date = NOW(),\n" .
    "  error_message=(?)",
    $self->{'config'}->{'mysql_table'}
  );
  my $stmt = $self->{'dbh'}->prepare($query);
  $stmt->execute($article_id, $reason, $reason);
  return;
}

######################################################################
sub check_subject($$)
######################################################################
{
    my ($self,$subject) = @_;
    my $query = $self->{'dbh'}->prepare("select count(subject) from  $self->{'config'}->{'mysql_table'} where subject=(?) and status='spam';");
    $query->execute($subject);
    my ($result) = @{$query->fetchrow_arrayref};
    return $result;
}

######################################################################
1;
######################################################################
