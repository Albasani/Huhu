######################################################################
#
# $Id: de_ch.pm 147 2009-10-13 14:46:07Z alba $
#
# Copyright 2009 Roman Racine
# Copyright 2009 Alexander Bartolich
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
package MOD::lang::de_ch;

use warnings;
use strict;
use Carp qw( confess );
use MOD::lang::de();

use constant TRANS => {
  'Pending' => 'Pendent',
  'Pending Posts' => 'Pendente Moderationsentscheidungen',
};
                                               
sub get_translator($)
{
  my $de = MOD::lang::de::get_translator(@_) || confess;
  return sub {
    my $result = TRANS->{$_[0]};
    return $result if ($result);
    $result = $de->(@_);
    return $result if ($result);
    return $_[0];
  };
}

1;
