#!/bin/sh
#
# $Id: create-mysql.sh 179 2009-11-07 15:19:03Z root $
#
export "LANG=C"
export "LC_ALL=C"
set -o nounset
set -o errexit

. "${HUHU_DIR}/sbin/create-functions.sh"
set_mysql_vars "$1"
create_mysql
