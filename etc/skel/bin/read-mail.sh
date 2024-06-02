#!/bin/sh
#
# This script tries to load all messages in the backup directory into the
# database. Because of the md5sum check this should be a safe operation,
# i.e. it is not possible to produce duplicates.
#
# Use this script for testing or in case the procmail rules were defunct.
#
export "LANG=C"
export "LC_CTYPE=C"
set -o nounset
set -o errexit

export HUHU_DIR="@HUHU_DIR@"
export PERL5LIB="${PERL5LIB:+$PERL5LIB:}${HUHU_DIR}"
"${HUHU_DIR}/bin/read-mail.pl" "-config=$HOME/etc/public.conf" "$HOME/backup"/*
