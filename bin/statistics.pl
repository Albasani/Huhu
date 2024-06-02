#!/usr/bin/perl -w
######################################################################
#
# $Id: statistics.pl 148 2009-10-13 15:02:22Z alba $
#
# Copyright 2009 Alexander Bartolich
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
######################################################################
use strict;
use warnings;
use MOD::Utils();
use MOD::DBIUtilsPublic();
use Data::Dumper;

######################################################################
sub format_time($)
######################################################################
{
  my ( $seconds ) = @_;

  my $hours = $seconds / 3600;
  $seconds %= 3600;
  my $minutes = $seconds / 60;
  $seconds %= 60;

  return sprintf '%02d:%02d:%02d', $hours, $minutes, $seconds;
}

######################################################################
sub format_item($)
######################################################################
{
  my ( $r ) = @_;

  return sprintf
    "%5d %9s %9s %9s %9s",
    $r->{'count'},
    format_time($r->{'min'}),
    format_time($r->{'max'}),
    format_time($r->{'avg'}),
    format_time($r->{'median'})
    ;
}

######################################################################
sub print_stats($$)
######################################################################
{
  my ( $status, $r_stats ) = @_;

  return unless ($r_stats->{'total'}->{'count'});

  print "\n";
  if ($status eq 'all')
    { print "    All posts.\n"; }
  else
    { printf "    Posts of type %s.\n", $status; }
  print "\n";

  for my $year(sort keys %$r_stats)
  {
    next if ($year eq 'total');
    my $r_month = $r_stats->{$year};

    for my $month(sort keys %$r_month)
    {
      next if ($month eq 'total');
      my $r_mday = $r_month->{$month};

      print "yyyy-mm-dd posts       min       max       avg    median\n";
      print "========================================================\n";
      for my $mday(sort keys %$r_mday)
      {
	next if ($mday eq 'total');
	my $r = $r_mday->{$mday};
	printf "%04d-%02d-%02d %s\n", $year, $month, $mday, format_item($r);
      }

      my $r = $r_mday->{'total'};
      print "--------------------------------------------------------\n";
      printf "%04d-%02d    %s\n", $year, $month, format_item($r);
      print "\n";
    }

    my $r = $r_month->{'total'};
    print "========================================================\n";
    printf "%04d       %s\n", $year, format_item($r);
    print "========================================================\n";
    print "\n";
  }

}

######################################################################
# MAIN
######################################################################

my %config = MOD::Utils::read_private_config($ARGV[0]);
my $db = MOD::DBIUtilsPublic->new(\%config);
my $statistics = $db->get_statistics();

my $all = $statistics->{'all'};

for my $status(
  'all',
  'pending',
  'moderated',
  'spam',
  'rejected',
  'deleted',
  'posted')
{
  print_stats($status, $statistics->{$status});
}

# print Dumper($statistics);

1;
