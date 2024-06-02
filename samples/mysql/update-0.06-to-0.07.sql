#
# $Id: update-0.06-to-0.07.sql 115 2009-09-20 10:09:22Z alba $
#
# Update from version 0.06 to 0.07

# First use create.sql to create table @sample@_error

# Copy columns errorcount and errormessage to table @sample@_error
INSERT INTO @sample@_error
(article_id, error_date, error_count, error_message)
SELECT a.id, NOW(), a.errorcount, a.errormessage
FROM @sample@ a
WHERE errorcount > 0;

# Drop columns errorcount and errormessage
ALTER TABLE @sample@ DROP column errorcount;
ALTER TABLE @sample@ DROP column errormessage;

# Test record:
# INSERT INTO @sample@_error (article_id, error_date, error_count, error_message) VALUES(10, NOW(), 17, 'huhu');
# INSERT INTO @sample@_error (article_id, error_date, error_count, error_message) VALUES(11, NOW(), 3, 'berta');
# SELECT * FROM @sample@_error;
