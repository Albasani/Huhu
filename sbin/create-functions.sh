#!/bin/sh
#
# $Id: create-functions.sh 290 2011-06-20 00:45:51Z alba $
#
set_mysql_vars()
{
  moderated_group="$1"

  # news.newusers.questions => nnq
  moderated_group_abbr=$( echo "${moderated_group}" |
    sed 's#\([a-zA-Z]\)[a-zA-Z]*\([^a-zA-Z]\|$\)#\1#g' )
  if [ -z "${moderated_group_abbr}" ]; then
    echo "${moderated_group} is not a valid newsgroup"
    exit 1
  fi

  # news.newusers.questions => news/newusers/questions
  www_dir=$( echo "${moderated_group}" | tr . / )

  # news.newusers.questions => news-newusers-questions
  mysql_db=$( echo "${moderated_group}" | tr . - )

  mysql_password=$( "${HUHU_DIR}/bin/new-passwd.pl" )
  mysql_table="${moderated_group_abbr}"
  mysql_username="${mysql_db}"

  length=$( echo "${mysql_username}" | wc -c )
  if [ "${length}" -gt 16 ]; then
    # http://dev.mysql.com/doc/refman/4.1/en/user-names.html
    # MySQL user names can be up to 16 characters long. 
    mysql_username="${moderated_group_abbr}"
  fi

  export today=$( date +%Y-%m-%d )
  export year=$( date +%Y )
}

create_mysql()
{
  local cmd="DROP USER '${mysql_username}'@'localhost'"

  if echo "${cmd}" | mysql
  then echo "${cmd} succeeded."
  else echo "${cmd} failed."
  fi

  mysqladmin create "${mysql_db}"
  (
    echo "CREATE USER '${mysql_username}'@'localhost' IDENTIFIED BY '${mysql_password}';"
    echo 'GRANT ALL ON `'${mysql_db}'`.* TO '"'${mysql_username}'@'localhost';"
  ) | mysql

  sed "s/@sample@/${mysql_table}/g" \
  < "${HUHU_DIR}/samples/mysql/create.sql" |
  mysql "${mysql_db}"

  echo "mysql_db=${mysql_db}"
  echo "mysql_table=${mysql_table}"
  echo "mysql_username=${mysql_username}"
  echo "mysql_password=${mysql_password}"
}

clean_new_home()
{
  cd "${1}" || exit 1

  # remove .svn or _svn directories copied from skeleton
  find . -type d -name '[._]svn' -exec rm -rf {} \+ 

  # remove backup files
  find . -type f -name '*~' -exec rm {} \+

  # property svn:executable is used to set the executable bit, so keep
  # u-permissions intact
  find . -type f -exec chmod o-rwx,g-rwx {} \+
}

install_file()
{
  permissions="$1"
  src="$2"
  dst="${user_home}/${src}"

  # template file was copied from skeleton by useradd
  # set safe permissions before we write sensitive contents into it
  chmod "${permissions}" "${dst}"

  awk '{
	gsub(/@HUHU_DIR@/, ENVIRON["HUHU_DIR"]);
	gsub(/@HUHU_WWW_BASE_DIR@/, ENVIRON["HUHU_WWW_BASE_DIR"]);
        gsub(/@HUHU_WWW_BASE_URL@/, ENVIRON["HUHU_WWW_BASE_URL"]);
	gsub(/@MODERATED_GROUP_ABBR@/, ENVIRON["moderated_group_abbr"]);
	gsub(/@MODERATED_GROUP@/, ENVIRON["moderated_group"]);
	gsub(/@MYSQL_DB@/, ENVIRON["mysql_db"]);
	gsub(/@MYSQL_PASSWORD@/, ENVIRON["mysql_password"]);
	gsub(/@MYSQL_TABLE@/, ENVIRON["mysql_table"]);
	gsub(/@MYSQL_USERNAME@/, ENVIRON["mysql_username"]);
	gsub(/@SUBMISSION_EMAIL@/, ENVIRON["user_name"] "@" ENVIRON["HUHU_EMAIL_DOMAIN"]);
	gsub(/@TODAY@/, ENVIRON["today"]);
	gsub(/@YEAR@/, ENVIRON["year"]);
	gsub(/@USER_HOME@/, ENVIRON["user_home"]);
	gsub(/@USER_ID@/, ENVIRON["user_id"]);
	gsub(/@USER_NAME@/, ENVIRON["user_name"]);
	gsub(/@WWW_DIR@/, ENVIRON["www_dir"]);
	print $0;
  }' "${skel_dir}/${src}" > "${dst}"
}

create_www_home()
{
  [ -n "${HUHU_WWW_BASE_DIR:-}" ] || return
  [ -n "${www_dir:-}" ] || return

  local dir="${HUHU_WWW_BASE_DIR}/${www_dir}/stats"
  [ -d "${dir}" ] || mkdir -p "${dir}"

  dir="${HUHU_WWW_BASE_DIR}/${www_dir}"
  (
    cd "${dir}"
    ln -s "${HUHU_DIR}/cgi-bin/modtable.pl"
    ln -s "${HUHU_DIR}/cgi-bin/public.pl"
  )
}
