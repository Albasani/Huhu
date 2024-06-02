#
# $Id: update-0.05-to-0.06.sql 102 2009-09-16 18:46:27Z alba $
#
# Update from version 0.05 to 0.06

# Check for errors (should return no rows)
SELECT status,posted FROM @sample@ WHERE posted and status <> 'moderated';
SELECT status,posted FROM @sample@ WHERE status = 0;

# Add value 'posted' to column 'status'.
ALTER TABLE @sample@ CHANGE Status Status enum('pending','spam','moderated','rejected','deleted','posted');

# Transfer column 'posted' to column 'status'.
UPDATE @sample@ SET Status = 'posted' WHERE posted;

# Remove column 'posted'.
ALTER TABLE @sample@ DROP column posted;
