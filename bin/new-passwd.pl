#!/usr/bin/perl -w
#######################################################################
#
# $Id: new-passwd.pl 164 2009-11-03 20:21:38Z alba $
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
use constant PRINTABLE =>
  '*+-./0123456789' .
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ' .
  'abcdefghijklmnopqrstuvwxyz';

for(my $i = 1; $i <= 8; $i++)
{
  print substr PRINTABLE, rand(length(PRINTABLE)), 1;
}
print "\n";
