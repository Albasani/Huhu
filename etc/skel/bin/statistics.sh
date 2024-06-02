#!/bin/sh
export "LANG=C"
export "LC_CTYPE=C"
set -o nounset
set -o errexit

export HUHU_DIR="@HUHU_DIR@"
export PERL5LIB="${PERL5LIB:+$PERL5LIB:}${HUHU_DIR}"
HTMLDIR=@HUHU_WWW_BASE_DIR@/@WWW_DIR@
"${HUHU_DIR}/bin/statistics.pl" "${HOME}/etc/public.conf" > "${HTMLDIR}/stats/stats.txt"
