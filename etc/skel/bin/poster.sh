#!/bin/sh
#
# This script tries to send all messages of status 'moderated' to the
# news server. This should be a safe operation, i.e. it is not possible
# to produce duplicates.
#
# Use this script for testing or after a configuration error.
#
export "LANG=C"
export "LC_CTYPE=C"
set -o nounset
set -o errexit

export HUHU_DIR="@HUHU_DIR@"
export PERL5LIB="${PERL5LIB:+$PERL5LIB:}${HUHU_DIR}"
"${HUHU_DIR}/bin/poster.pl" "$HOME/etc/public.conf"
