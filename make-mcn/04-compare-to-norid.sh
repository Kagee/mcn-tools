#! /bin/bash

if [ ! -d "$JOBDIR" ]; then
  if [ ! -d "$1" ]; then
    1>&2 echo "${BASH_SOURCE[0]} requires one argument (the JOBDIR) as \$1 or \$JOBDIR";
    exit 1;
  else
    JOBDIR="$1"
  fi
fi

COMBINED="$JOBDIR/result_SOA_combined.txt"

if [ ! -f "$COMBINED" ] || [[ $(find $JOBDIR/ -name 'result_SOA.*.json' -newer $COMBINED) ]]; then
  1>&2 echo "[INFO] Updating combined result list"
  INPUT_LIST="$(find $JOBDIR/ -name 'result_SOA.*.json')"
  cat $INPUT_LIST | jq -r 'select(.status == "NOERROR") .name' | sort | uniq > "$COMBINED"
else
  echo "[INFO] Keeping old combined results list"
fi


URL_TOTAL="https://www.norid.no/en/statistikk/aktivedomener"
FTOT="./aktivedomener.html"
#https://www.norid.no/en/statistikk/privtall/ #private REGISTRANT, not under .priv.no
URL_IDN="https://www.norid.no/en/statistikk/idntall"
FIDN="./idntall.html"


if [ ! -f "$FTOT" ] || [[ $(find "$FTOT" -mtime +1 -print) ]]; then
  1>&2 echo "[INFO] Downloading $FTOT from Norid."
  wget -q -O "$FTOT" "$URL_TOTAL"
else
  1>&2 echo "[INFO] Found old $FTOT, using that."
fi

TOT="$(cat "$FTOT"| grep -P '\d\d\d\d-\d\d-\d\d' | head -1 | rev | cut -d';' -f -1 | rev)"

if [ ! -f "$FIDN" ] || [[ $(find "$FTOT" -mtime +1 -print) ]]; then
  1>&2 echo "[INFO] Downloading $FIDN from Norid"
  wget -q -O "$FIDN" $URL_IDN
else
  1>&2 echo "[INFO] Found old $FIDN, using that."
fi

IDN="$(cat $FIDN | grep -P '\d\d\d\d-\d\d-\d\d' | head -1 | cut -d\; -f4 | cut -d\& -f 1)"
1>&2 echo "[INFO] Comparison to known numbers:"
1>&2 echo "[INFO] Norid:"
1>&2 echo "[INFO]   Total domains: $TOT"
1>&2 echo "[INFO]   IDN Domains: $IDN"

ITOT="$(wc -l "$COMBINED" | cut -d ' ' -f 1)"
IIDN="$(grep "^xn--" "$COMBINED" | wc -l | cut -d ' ' -f 1)"

1>&2 echo "[INFO] Input data:"
1>&2 echo "[INFO]   Total domains: $ITOT"
1>&2 echo "[INFO]   IDN Domains: $IIDN"

PTOT="$(printf $(echo "scale=4; $ITOT/$TOT * 100" | bc | cut -d . -f 1)%%)"
PIDN="$(printf $(echo "scale=4; $IIDN/$IDN * 100" | bc | cut -d . -f 1)%%)"
DTOT="$( echo "$TOT - $ITOT" | bc)"
DIDN="$( echo "$IDN - $IIDN" | bc)"

1>&2 echo "[INFO] Comparison:"
1>&2 echo "[INFO]   Total domains: $PTOT, diff $DTOT"
1>&2 echo "[INFO]   IDN Domains: $PIDN, diff $DIDN"

1>&2 echo "[INFO] Statistics:"
1>&2 echo "[INFO]   Norske kommuner og herredskommuner (*.kommune.no, *.herad.no): $(grep -c -P '.*\.kommune\.no$|.*\.herad\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Den norske stat og departementene (*.dep.no, *.stat.no): $(grep -c -P '.*\.dep\.no$|.*\.stat\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Privatpersoner (*.priv.no): $(grep -c -P '.*\.priv\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Folkehøgskoler og videregående skoler (*.fhs.no, *.vgs.no): $(grep -c -P '.*\.fhs\.no$|.*\.vgs\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Fylkesbiblioteker og folkebiblioteker (*.fylkesbibl.no, *.folkebibl.no): $(grep -c -P '.*\.fylkesbibl\.no$|.*\.folkebibl\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Museer (*.museum.no): $(grep -c -P '.*\.museum\.no$' "$COMBINED")"
1>&2 echo "[INFO]   Idrettsorganisasjoner (*.idrett.no): $(grep -c -P '.*\.idrett\.no$' "$COMBINED")"

1>&2 echo "[INFO] Comparison to input files"

INPUT="$(./00-make-input.sh)"
MATCH_STATS="$(echo "$INPUT" | grep -o -P '[^\s]*\.list' | while read F;
 do
    wc -l "$F"
done | sort -g | awk '{print $2}' | while read F;
do
  SOURCE="$(echo $F | sed 's/.*-\([^-]*\).list/\1/')"
  FILE_TOTAL="$(grep -c -P '.*' "$F")"
  FILE_MATCHES="$(grep -x -F -f "$COMBINED" -c "$F")"
  FILE_DIFF="$(echo "$FILE_TOTAL - $FILE_MATCHES" | bc)"
  echo -e "[INFO] $SOURCE\t$FILE_TOTAL\t$FILE_MATCHES\t$FILE_DIFF\t$(printf $(echo "scale=4; $FILE_MATCHES/$FILE_TOTAL * 100" | bc | cut -d . -f 1)%%)"
done | sort -k6 -g -r)"

echo -e "[INFO] SOURCE\tFILE_TOTAL\tFILE_MATCHES\tFILE_DIFF\tPERCENT\n$MATCH_STATS" | column -t
