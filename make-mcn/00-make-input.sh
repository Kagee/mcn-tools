#! /bin/bash
source config.sh
find $MCN_PATHS -type f -path '*/mcn-source-*/output/*' -name '*.list' | sort
