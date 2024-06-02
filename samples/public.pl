#!/usr/bin/perl 

use strict;
use warnings;
use CGI::Carp 'fatalsToBrowser';
$ENV{'CONTENT_TYPE'} = "multipart/form-data";
 
BEGIN {
   push (@INC,'/srv/www/huhu/');
}
require MOD::PublicHandler;

my $h = MOD::PublicHandler->new('/srv/www/SAMPLE/home/etc/SAMPLE_pub.config');
$h->run();
