#! /bin/bash

if [ ! -d "$JOBDIR" ]; then
  if [ ! -d "$1" ]; then
    1>&2 echo "${BASH_SOURCE[0]} requires one argument (the JOBDIR) as \$1 or \$JOBDIR";
    exit 1;
  else
    JOBDIR="$1"
  fi
fi

INPUT_LIST="$(find $JOBDIR/ -name 'result_SOA.*.json')"

1>&2 echo "[INFO] no know how make json to txt"

exit 9

URL_TOTAL="https://www.norid.no/en/statistikk/aktivedomener"
FTOT="./aktivedomener"
#https://www.norid.no/en/statistikk/privtall/ #private REGISTRANT, not under .priv.no
URL_IDN="https://www.norid.no/en/statistikk/idntall"
FIDN="./idntall"


if [ ! -f "$FTOT" ]; then
wget -q -O "$FTOT" "$URL_TOTAL"
else
  1>&2 echo "[INFO] Found old $FTOT, using that. Delete to refresh."
fi

TOT="$(cat "$FTOT"| grep -P '\d\d\d\d-\d\d-\d\d' | head -1 | rev | cut -d';' -f -1 | rev)"

if [ ! -f "$FIDN" ]; then
wget -q -O "$FIDN" $URL_IDN
else
  1>&2 echo "[INFO] Found old $FIDN, using that. Delete to refresh."
fi

IDN="$(cat $FIDN | grep -P '\d\d\d\d-\d\d-\d\d' | head -1 | cut -d\; -f4 | cut -d\& -f 1)"

1>&2 echo ""
1>&2 echo "[INFO] Norid:"
1>&2 echo "[INFO]   Total domains: $TOT"
1>&2 echo "[INFO]   IDN Domains: $IDN"
1>&2 echo ""

ITOT="$(wc -l "$INPUT_LIST" | cut -d ' ' -f 1)"
IIDN="$(grep "^xn--" "$INPUT_LIST" | wc -l | cut -d ' ' -f 1)"

1>&2 echo "[INFO] Input data:"
1>&2 echo "[INFO]   Total domains: $ITOT"
1>&2 echo "[INFO]   IDN Domains: $IIDN"
1>&2 echo ""

PTOT="$(printf $(echo "scale=4; $ITOT/$TOT * 100" | bc | cut -d . -f 1)%%)"
PIDN="$(printf $(echo "scale=4; $IIDN/$IDN * 100" | bc | cut -d . -f 1)%%)"
DTOT="$( echo "$TOT - $ITOT" | bc)"
DIDN="$( echo "$IDN - $IIDN" | bc)"

1>&2 echo "[INFO] Comparison:"
1>&2 echo "[INFO]   Total domains: $PTOT, diff $DTOT"
1>&2 echo "[INFO]   IDN Domains: $PIDN, diff $DIDN"
1>&2 echo ""

1>&2 echo "[INFO] Statistics:"
1>&2 echo "[INFO]   Norske kommuner og herredskommuner (*.kommune.no, *.herad.no): $(grep -c -P '.*\.kommune\.no$|.*\.herad\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Den norske stat og departementene (*.dep.no, *.stat.no): $(grep -c -P '.*\.dep\.no$|.*\.stat\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Privatpersoner (*.priv.no): $(grep -c -P '.*\.priv\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Folkehøgskoler og videregående skoler (*.fhs.no, *.vgs.no): $(grep -c -P '.*\.fhs\.no$|.*\.vgs\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Fylkesbiblioteker og folkebiblioteker (*.fylkesbibl.no, *.folkebibl.no): $(grep -c -P '.*\.fylkesbibl\.no$|.*\.folkebibl\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Museer (*.museum.no): $(grep -c -P '.*\.museum\.no$' "$INPUT_LIST")"
1>&2 echo "[INFO]   Idrettsorganisasjoner (*.idrett.no): $(grep -c -P '.*\.idrett\.no$' "$INPUT_LIST")"
