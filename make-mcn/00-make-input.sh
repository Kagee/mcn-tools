#! /bin/bash
source config.sh
find $MCN_PATHS -type f -path '*/mcn-source-*/output/*' -name '*.list' | sort | \
  while read -r F; do
    BASE="$(dirname "$(dirname $F)")"
    SOURCE="$(basename "$BASE" | sed 's/mcn-source-//')"
    CREDITS="$(grep -E 'Credits?:' "$BASE/README.md" 2>/dev/null| head -1 | sed 's/Credits*: *//')"
    stat="$(stat --printf="%Y %F\n" "$F")"
    DAYS="$((($(date +%s) - ${stat%% *})/86400))"
    echo "$DAYS;$SOURCE;$F;$CREDITS";
  done | sort -g | awk 'BEGIN{FS=";"} { if ( $1 > 14 ) { $1 = "\033[33m"$1" days\033[0m"; } else { $1 = $1" days" }  print "Source: "$2" ("$1" days)\nFile: "$3"\nCredits: "$4"\n" }'
