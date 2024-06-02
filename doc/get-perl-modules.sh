#!/bin/sh
#
# $Id: $
#
# Search for required Perl modules, translate to required package names.
#
export "LANG=C"
export "LC_ALL=C"
set -o nounset
set -o errexit

req_modules="required-perl-modules.txt"
req_deb="required-deb-packages.txt"
req_rpm="required-rpm-packages.txt"

find "${HUHU_DIR}" -type f -name '*.p[lm]' -exec \
gawk -F '[[:space:]();]+' '
  $1 == "use" && $2 ~ /::/ && $2 !~ /^MOD::/ { print $2 }
' {} \+ |
sort -u > "${req_modules}"

if [ -f /etc/debian_version ]; then
  xargs locate < "${req_modules}" |
  sort -u |
  xargs -n1 dpkg -S |
  sed -ne 's/: .*//p' |
  sort -u > "${req_deb}"
elif [ -f /etc/redhat-release ]; then
  xargs locate < "${req_modules}" |
  sort -u |
  xargs rpm -qf |
  sed -e '/ /d' |
  sort -u > "${req_rpm}"
fi


