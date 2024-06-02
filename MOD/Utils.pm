######################################################################
#
# $Id: Utils.pm 272 2010-05-28 19:46:29Z root $
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
#
# This package contains some frequently used routines
#
######################################################################
package MOD::Utils;

use warnings;
use strict;
use Carp qw( confess );
use News::Article();
use I18N::AcceptLanguage();

use MOD::lang::en_us();

@MOD::Utils::ISA = qw(Exporter);
@MOD::Utils::EXPORT = qw();
@MOD::Utils::EXPORT_OK = qw(
  read_public_config
  read_private_config
);

######################################################################

our @SUPPORTED_LANG;
our %SUPPORTED_LANG;

# cache of public configuration file
# key = filename, value = [ mtime, r_config ]
our %CONFIG_CACHE;

######################################################################
sub get_cache_entry($)
######################################################################
{
  my $filename = shift || confess 'No parameter $filename';
  my $r_cache = $CONFIG_CACHE{$filename};
  return undef if (!$r_cache);
  
  my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size, $atime,
    $mtime, $ctime, $blksize, $blocks) = stat($filename);
  die "Can't access $filename:$!" if (!$mtime);

  return ($r_cache->[0] < $mtime) ? undef : $r_cache->[1];
}

######################################################################
sub add_cache_entry($$)
######################################################################
{
  my $filename = shift || confess 'No parameter $filename';
  my $r_config = shift || confess 'No parameter $r_config';

  $CONFIG_CACHE{$filename} = [ time(), $r_config ];
}

######################################################################
sub read_config_file($$)
######################################################################
{
  my $filename = shift || confess 'No parameter $filename';
  my $r_hash = shift || confess 'No parameter $r_hash';

  my $conf;
  open($conf, '<', $filename) ||
    die "Can't open configuration file: \n$!\n$filename";
  while(my $line = <$conf>)
  {
    next if ($line =~ /^\s*#/);
    my ($name, $val) = split (/[ \t]*=[ \t]*/, $line, 2);
    # ignore undefined $val and zero-length $val
    next if (!$val);
    $name =~ s/^\s+//;
    $val =~ s/\s+$//;
    $val =~ s/^"(.*)"$/$1/;
    $r_hash->{$name} = $val;
  }
}

######################################################################
# Read the public config file, returns a hash of settings.
######################################################################
sub read_public_config($)
######################################################################
{
  my $filename = shift || confess 'No parameter $filename';
  my $r_config = get_cache_entry($filename);
  if ($r_config) { return %$r_config; }

  my %config_vars =
  (
    'mysql_password' => $ENV{'mysql_password'}
  );
  read_config_file($filename, \%config_vars);
  add_cache_entry($filename, \%config_vars);
  return %config_vars;
}

######################################################################
# Read the private config file, returns a hash of settings.
#
# The function first reads the public file to read the values of
# 'UID' and 'priv_config_file'.
# 
# The function dies
# - if 'UID' or 'priv_config_file' are not defined
# - if user id (variable "$<") does not match the setting of "UID"
# - if the private file cannot be opened
######################################################################
sub read_private_config($)
######################################################################
{
  my $filename = shift || confess 'No parameter $filename';
  my %config_vars = read_public_config($filename);

  my $cfg_uid = $config_vars{'UID'} ||
    die 'No "UID" in public configuration file $filename"';
  if ($< != $cfg_uid)
  {
    die "Execution of this function is not allowed for user ID $<!\n";
  }

  my $priv_file = $config_vars{'priv_config_file'} ||
    die "No 'priv_config_file' in public configuration file $filename";
  read_config_file($priv_file, \%config_vars);
  return %config_vars;
}

######################################################################
sub get_supported_translators()
######################################################################
{
  return @SUPPORTED_LANG if (@SUPPORTED_LANG);

  my $pkgname = __PACKAGE__;    # value of __PACKAGE__ is "MOD::Utils"
  $pkgname =~ s#.*::##g;        # reduce to "Utils"
  my $pkgdir = __FILE__;        # __FILE__ is "/srv/www/huhu/MOD/Utils.pm"
  $pkgdir =~ s#$pkgname\.pm$##; # reduce to "/srv/www/huhu/MOD/"
  $pkgdir .= 'lang';

  # String constants in this software are written in American English.
  @SUPPORTED_LANG = ( 'en-us' );
  %SUPPORTED_LANG = ( 'en-us' => undef );

  my $dirhandle;

  opendir($dirhandle, $pkgdir) || die "opendir $pkgdir: $!";
  for my $lang( grep { /^\w+\.pm$/ && -f "$pkgdir/$_" } readdir($dirhandle) )
  {
    $lang =~ s#\.pm$##;
    # Perl dows not allow '-' in module names, so we use '_' instead.
    # The strings in HTTP_ACCEPT_LANGUAGE use '-', however.
    $lang =~ s#_#-#g;
    $SUPPORTED_LANG{$lang} = undef;
    push @SUPPORTED_LANG, $lang;
  }
  closedir($dirhandle);

  return @SUPPORTED_LANG;
}

######################################################################
sub get_translator_language($$)
######################################################################
{
  my $lang = shift;
  my $negotiate = shift;

  get_supported_translators();

  if ($negotiate && exists($ENV{ 'HTTP_ACCEPT_LANGUAGE' }))
  {
    # Sample value for HTTP_ACCEPT_LANGUAGE:
    #   de-at,en-us;q=0.7,en;q=0.3
    my $a = I18N::AcceptLanguage->new( $lang );
    my $n = $a->accepts($ENV{HTTP_ACCEPT_LANGUAGE}, \@SUPPORTED_LANG);

    $lang = $n if (defined($n) && exists($SUPPORTED_LANG{ $n }));
  }

  if ($lang)
  {
    unless(exists($SUPPORTED_LANG{ $lang }))
    {
      die "Unsupported language '$lang' (choose one of " .
	join(', ', @SUPPORTED_LANG) . ')';
    }
    return $lang;
  }

  return $SUPPORTED_LANG[0];
}

######################################################################
sub get_translator($)
######################################################################
{
  my $lang = shift;
  if ($lang)
  {
    unless(exists($SUPPORTED_LANG{ $lang }))
    {
      die "Unsupported language '$lang' (choose one of " .
	join(', ', @SUPPORTED_LANG) . ')';
    }

    # Perl dows not allow '-' in module names, so we use '_' instead.
    # The strings in HTTP_ACCEPT_LANGUAGE use '-', however.
    $lang =~ s#-#_#g;

    my $module = __PACKAGE__;      # value of __PACKAGE__ is "MOD::Utils"
    $module =~ s#::[^:]+$##g;      # reduce to "MOD"
    $module .= '::lang::' . $lang; # extend to "MOD::lang::en"

    eval "use $module;";
    if (length($@) == 0)
    {
      no strict;
      my $get = eval '*{$' . $module . '::{"get_translator"}}{"CODE"}';
      if (length($@) == 0)
      {
        my $trans = return $get->($lang);
        return $trans if $trans;
      }
    }
  }

  return MOD::lang::en_us::get_translator($lang);
}

######################################################################
1;
######################################################################
