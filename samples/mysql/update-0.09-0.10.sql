#
# $Id: update-0.07-0.08.sql 121 2009-09-20 15:32:22Z alba $
#
# Update from version 0.07 to 0.08

ALTER TABLE @sample@ CHANGE COLUMN Status
Status ENUM('pending','spam','moderated','rejected','deleted','posted','sending','broken') NOT NULL;

