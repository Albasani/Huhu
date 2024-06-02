#!/bin/bash
export HUHU_DIR="@HUHU_DIR@"
export PERL5LIB="${PERL5LIB:+$PERL5LIB:}${HUHU_DIR}"
export PATH="${PATH}:${HUHU_DIR}/bin"
