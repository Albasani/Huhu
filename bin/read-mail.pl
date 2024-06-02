#!/usr/bin/perl -ws
######################################################################
#
# $Id: read-mail.pl 306 2012-01-31 16:59:35Z root $
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

use Carp qw(confess);
use News::Article();
use MOD::Utils();
use MOD::ReadMail();

######################################################################
sub parse_text($)
######################################################################
{
  my $text = shift || confess;

  my $article = News::Article->new($text);
  if (!$article)
  {
    print STDERR "Error: Parsing mail with News::Article failed.\n";
    return undef;
  }

  my $bytes = $article->bytes();
  if ($bytes <= 2)
  {
    print STDERR "Error: Article too small, bytes=$bytes\n";
    return undef;
  }

  return $article;
}

######################################################################
sub skip_empty_lines($$$)
######################################################################
{
  my ($body, $start, $stop) = @_;

  my @result;
  push(@result, $body->[$start - 1]) if ($start > 0);

  for(my $i = $start; $i <= $stop; $i += 2)
  {
    if (length($body->[$i]) != 0)
    {
      printf STDERR "check_for_empty_lines i=%d %s\n", $i, $body->[$i];
      return undef;
    }
    push @result, $body->[$i + 1];
  }
  return \@result;
}

######################################################################
sub test_article($$$)
######################################################################
{
  my ($rm, $article, $filename) = @_;

  my $lines = $article->header('Lines');
  if (!$lines)
  {
    printf STDERR "Warning: No Lines header.\n";
    return 0;
  }

  my @body = $article->body();
  my $delta = $lines * 2 - $#body;
  if (abs($delta) <= 2)
  {
    print $filename, "\n";
    printf "body: %d\n", $#body;
    printf "Lines: %d\n", $article->header('Lines');

    my $new_body = skip_empty_lines(\@body, 1, $#body);
    if (!$new_body)
    {
      $new_body = skip_empty_lines(\@body, 0, $#body); 
      return 0 if (!$new_body);
    }

    printf "new_body=%d\n", $#$new_body;
    print join("\n", @$new_body);
  }
  return 0;
}

######################################################################
sub process_text($$$)
######################################################################
{
  my ($rm, $article, $filename) = @_;

  my $rc = eval { $rm->add_article($article, $::status); };
  if ($@)
  {
    print STDERR "add_article failed, $@\n";
    return 0;
  }
  if (!$rc)
  {
    printf STDERR "add_article(%s) failed, rc=%s\n",
      $::status ? $::status : '',
      $rc;
    return 0;
  }
}

######################################################################
# MAIN
######################################################################

die 'Argument -config=file missing' unless($::config);
$::status = undef unless($::status); # to suppress warning
$::stdin = undef unless($::stdin); # to suppress warning

my %config = MOD::Utils::read_private_config($::config);
my $rm = MOD::ReadMail->new(\%config);

my $fn = $::test ? \&test_article : \&process_text;

if ($::stdin)
{
  my $text = do { local $/; <STDIN>; };
  die "Error: No data on stdin" unless ($text);
  my $article = parse_text(\$text) || exit(1);
  $fn->($rm, $article, '<STDIN>');
}
else
{
  for my $name(@ARGV)
  {
    my $file;
    open($file, '<', $name) || die "Error: Can't open $name\n$!";
    my $text = do { local $/; <$file>; };
    close($file);
    my $article = parse_text(\$text) || next;
    $fn->($rm, $article, $name);
  }
}

######################################################################
