#
# $Id: update-0.08-0.09.sql 145 2009-10-11 20:00:45Z alba $
#
# Update from version 0.08 to 0.09

# First use create.sql to create table @sample@_reply

# Copy column Answer to table @sample@_reply
INSERT INTO @sample@_reply
(article_id, reply_date, reply_message)
SELECT a.id, IFNULL(a.Moddatum, NOW()), a.answer
FROM @sample@ a
WHERE a.answer is not null;

# Drop column Answer
ALTER TABLE @sample@ DROP COLUMN answer;
