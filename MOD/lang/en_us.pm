######################################################################
#
# $Id: en_us.pm 273 2010-05-28 21:22:31Z root $
#
# Copyright 2009 Roman Racine
# Copyright 2009-2010 Alexander Bartolich
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
package MOD::lang::en_us;

use warnings;
use strict;

use constant TRANS => {
  '_ALREADY_HANDLED' => 'This entry was already handled by another moderator.',
  '_ARRIVAL_NOTICE_BODY' => "One or more of your posts are pending in the moderation queue.\nThis message was generated automatically.\n",
  '_ARRIVAL_NOTICE_SUBJECT' => '[%s] Post received',
  'article_sender' => 'Sender',
  'article_status' => 'Status',
  'article_subject' => 'Subject',
  '_CROSSPOSTED' => 'Note that this message is crossposted to more than two groups!',
  'error_count' => 'Error Count',
  'error_date' => 'Date',
  '_ERROR_GONE' => 'The error message is gone, probably because its cause is fixed.',
  '_ERROR_INVALID_ADDRESS' => 'Invalid address, can\'t send mail.',
  'error_message' => 'Error Message',
  '_EXPLAIN_REASON' => 'Here you can state a reason why the message was deleted. This text is visible only to other members of the moderation team.',
  '_SUBTITLE_APPROVED' => 'Approved posts that are not sent, yet.',
  '_SUBTITLE_DELETED' => 'Posts that are silently ignored.',
  '_SUBTITLE_ERROR' => 'Approved posts that could not be sent. Will be retried automatically.',
  '_SUBTITLE_PENDING' => 'Posts waiting for your decision.',
  '_SUBTITLE_POSTED' => 'Approved posts that were sent to the newsserver.',
  '_SUBTITLE_REJECTED' => 'Posts where the sender was sent a reason why they were not approved.',
  '_SUBTITLE_SPAM' => 'Posts classified as spam by the spam filter or a moderator.',
};
                                               
sub get_translator($)
{
  return sub {
    my $result = TRANS->{$_[0]};
    return $result ? $result : $_[0];
  };
}

1;
