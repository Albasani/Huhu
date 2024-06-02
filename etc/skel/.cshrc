#!/bin/csh -x
setenv EDITOR           /usr/bin/vim
setenv GREP_OPTIONS     '--color=auto'

setenv LC_CTYPE         C
setenv LANGUAGE         en_US
setenv LANG             "${LANGUAGE}.iso885915"

setenv HUHU_DIR		"@HUHU_DIR@"
setenv PERL5LIB		"${HUHU_DIR}"
