#
# $Id: create.sql 304 2011-11-02 14:14:01Z root $
#
# Create statement for mysql. Replace @sample@ with your table prefix.
# For example:
#    sed 's/@sample@/atm/g' < create.sql
#
CREATE TABLE @sample@ (
  ID bigint NOT NULL auto_increment,
  # 'spam'      ... can be put back to 'pending' queue
  # 'moderated' ... tells poster.pl to send the message,
  #                 can be put back to 'pending' queue
  # 'rejected'  ... a mail was sent to the author - cannot be undone
  # 'deleted'   ... can be put back to 'pending' queue
  # 'posted'    ... message was sent to server - cannot be undone
  # 'sending'   ... poster.pl is trying to send article to server,
  #                 next state is 'moderated', 'posted', or 'broken'
  # 'broken'    ... poster.pl encountered a fatal error
  Status ENUM(
    'pending',
    'spam',
    'moderated',
    'rejected',
    'deleted',
    'posted',
    'sending',
    'broken'
  ) NOT NULL,
  Sender text NOT NULL,
  ReplyTo text,
  Subject text NOT NULL,
  MessageID text DEFAULT NULL,
  Datum DATETIME NOT NULL,
  Header longblob NOT NULL,
  Body longblob NOT NULL,
  Spamcount float DEFAULT 0.0,
  Moderator varchar(20),
  Moddatum DATETIME,
  checksum char(40) UNIQUE,
  flag bool DEFAULT 0,
  PRIMARY KEY (ID),
  KEY(status),
  KEY(Datum),
  KEY(Moddatum),
  KEY(checksum),
  KEY(subject(40)),
  KEY(flag)
);

# DROP TABLE @sample@_error;
CREATE TABLE @sample@_error (
  error_id BIGINT NOT NULL AUTO_INCREMENT,
  article_id BIGINT,
  error_date DATETIME NOT NULL,
  # Number of duplicate (article_id,error_message) tuples.
  error_count INT(2) DEFAULT 0 NOT NULL,
  error_message TEXT,
  PRIMARY KEY (error_id),
  UNIQUE(article_id, error_message(40)),
  FOREIGN KEY (article_id) REFERENCES @sample@(id) ON DELETE CASCADE
);

CREATE OR REPLACE VIEW @sample@_error_view AS
SELECT	id,
	flag,
	sender AS article_sender,
	subject AS article_subject,
	status AS article_status,
	error_id,
	error_date,
	error_count,
	error_message
FROM @sample@_error AS _error
LEFT JOIN (@sample@ AS _article)
ON _error.article_id = _article.id;

# DROP TABLE @sample@_reply;
CREATE TABLE @sample@_reply (
  reply_id BIGINT NOT NULL AUTO_INCREMENT,
  article_id BIGINT,
  reply_date DATETIME NOT NULL,
  reply_message TEXT,
  PRIMARY KEY (reply_id),
  KEY(article_id),
  FOREIGN KEY (article_id) REFERENCES @sample@(id) ON DELETE CASCADE
);
