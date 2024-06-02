#!/bin/sh
######################################################################
#
# $Id: mk-gpg-key.sh 291 2011-06-21 13:19:54Z alba $
#
######################################################################
export "LANG=C"
export "LC_ALL=C"
set -o nounset
set -o errexit

public="${HOME}/etc/public.conf"
if [ ! -s "${public}" ]; then
  echo "ERROR: Public configuration file does not exist."
  echo "public=${public}"
  exit 1
fi

private=$(
  sed -ne '/^priv_config_file=/ { s///; p; q }' "${public}"
)
if [ ! -s "${private}" ]; then
  echo "ERROR: Private configuration file does not exist."
  echo "private=${private}"
  exit 1
fi

passphrase=$(
  sed -ne '/^pgp_passphrase=/ { s///; p; q }' "${private}"
)
name_real=$(
  sed -ne '/^pgp_keyid=\(.*\)<.*/ { s//\1/; s/ *$//; p; q }' "${private}"
)
name_email=$(
  sed -ne '/^pgp_keyid=.*<\([^>]*\)>.*/ { s//\1/; p; q }' "${private}"
)

echo "passphrase=${passphrase}"
echo "name_real=${name_real}"
echo "name_email=${name_email}"

if [ -n "${name_real:-}" -a -n "${name_email:-}" ]; then
  (
    # See /usr/share/doc/gnupg/DETAILS.gz for parameter description
    echo "Key-Type: 1"
    echo "Key-Length: 2048"
    echo "Name-Real: ${name_real}"
    echo "Name-Email: ${name_email}"
    [ -n "${passphrase:-}" ] && echo "Passphrase: ${passphrase}"
    echo "Expire-Date: 10y"
    echo "%commit"
    echo "%echo done"
  ) | gpg --gen-key --batch
  gpg --list-keys
fi
