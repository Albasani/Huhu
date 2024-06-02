#!/bin/sh -x
#
# $Id: create-procmail-user.sh 290 2011-06-20 00:45:51Z alba $
#
export "LANG=C"
export "LC_ALL=C"
set -o nounset
set -o errexit

if [ -z "${1:-}" ]; then
  echo "USAGE: create-procmail-user.sh <moderated_group>"
  exit 0
fi

. "${HUHU_DIR}/sbin/create-functions.sh"
set_mysql_vars "$1"
create_mysql

# mysql_username may be an abbreviation, so use mysql_db
user_name="${mysql_db}"

skel_dir="${HUHU_DIR}/etc/skel"
if [ ! -d ${skel_dir} ]; then
  echo "Skeleton directory \$HUHU_DIR/etc/skel does not exist."
  exit 1
fi

user_home="${HUHU_HOME_BASE_DIR:-/home}/"$( echo "${user_name}" | sed 's#[-.]#/#g' )
user_home_parent="${user_home%/*}"
[ -d "${user_home_parent}" ] || mkdir -p "${user_home_parent}"
useradd --home "${user_home}" --create-home --skel "${skel_dir}" "${user_name}"

user_home=$( awk -F: "/^${user_name}:/ { print \$6 }" /etc/passwd )

if [ ! -d "${user_home}" ]; then
  echo "Home directory of user ${user_name} does not exist."
  exit 1
fi
user_id=$( awk -F: "/^${user_name}:/ { print \$3 }" /etc/passwd )

clean_new_home "${user_home}"
create_www_home

export moderated_group moderated_group_abbr
export mysql_db mysql_password mysql_table mysql_username
export user_home user_id user_name www_dir

if [ -n "${HUHU_EMAIL_DOMAIN:-}" ]; then
  if [ -n "${HUHU_EMAIL_LIST:-}" -a -w "${HUHU_EMAIL_LIST:-}" ]; then
    echo "${user_name}@${HUHU_EMAIL_DOMAIN}" >> "${HUHU_EMAIL_LIST}"
  fi
  if [ -n "${HUHU_POSTFIX_ALIAS:-}" -a -w "${HUHU_POSTFIX_ALIAS:-}" ]; then
    echo "${user_name}@${HUHU_EMAIL_DOMAIN} ${user_name}" >> "${HUHU_POSTFIX_ALIAS}"
  fi
fi

install_file 600 .bashrc
install_file 600 .cshrc
install_file 600 etc/private.conf
install_file 600 etc/samples/apache-digest.conf
install_file 600 etc/samples/crontab
install_file 600 etc/samples/summary.txt
install_file 600 .forward
install_file 600 .my.cnf
install_file 600 .procmailrc
install_file 644 etc/htdigest
install_file 644 etc/public.conf
install_file 644 etc/samples/huhu-directory.html
install_file 755 bin/poster.sh
install_file 755 bin/read-mail.sh
install_file 755 bin/statistics.sh
install_file 755 etc/htdigest.sh

crontab -u "${user_name}" "${user_home}/etc/samples/crontab"
