#!/usr/bin/perl -w
use strict;
use warnings;
use CGI::Carp 'fatalsToBrowser';

$ENV{'CONTENT_TYPE'} = "multipart/form-data";

BEGIN { push (@INC, $ENV{'HUHU_DIR'}); }

use MOD::Handler;
my $h = MOD::Handler->new( $ENV{'HUHU_PUB_CONFIG'} );
$h->run();
