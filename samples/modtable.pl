#!/usr/bin/perl -w

use strict;
use warnings;
$ENV{'CONTENT_TYPE'} = "multipart/form-data";

use CGI::Carp 'fatalsToBrowser';

BEGIN { 
   push (@INC,'/srv/www/huhu');
}

use MOD::Handler;
my $h = MOD::Handler->new('/srv/www/sample/home/etc/sample_pub.config');
$h->run();
