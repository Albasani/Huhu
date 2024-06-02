#!/bin/sh
######################################################################
#
# $Id: ircbot.sh 283 2011-02-18 00:17:33Z alba $
#
######################################################################
export "LANG=C"
export "LC_ALL=C"
set -o nounset
set -o errexit

pidfile="${HOME}/var/ircbot.pid"
logfile="${HOME}/var/ircbot.log"
config="${HOME}/etc/public.conf"

do_stop()
{
  if [ -s "${pidfile}" ]; then
    kill $(cat "${pidfile}") || echo status=$?
    rm "${pidfile}"
  fi
}

do_start()
{
  ${HUHU_DIR}/bin/ircbot.pl "-config=${config}" "-pidfile=${pidfile}" \
  > "${logfile}" 2>&1 &
}

case "${1:-}" in
  start)   do_start ;;
  restart) do_stop; do_start ;;
  stop)    do_stop ;;
  *) echo "Usage: ircbot.sh {start|stop|restart}"
     exit 3
     ;;
esac
