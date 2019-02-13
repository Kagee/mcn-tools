#! /bin/bash

if [ ! -d "$JOBDIR" ]; then
  if [ ! -d "$1" ]; then
    1>&2 echo "${BASH_SOURCE[0]} requires one argument (the JOBDIR) as \$1 or \$JOBDIR"; 
    exit 1;
  else
    JOBDIR="$1"
  fi
fi

INPUT_LIST="$JOBDIR/full_uniq_post_idn.list"
1>&2 echo "[INFO] massdns input list i $INPUT_LIST"

MINUTE="$(date +%F-%H-%M)"
OUTFILE="$JOBDIR/result_SOA.${MINUTE}.json"
OUTERR="$JOBDIR/result_SOA.${MINUTE}.json.error"
1>&2 echo "[INFO] massdns output file is $OUTFILE"
$MD -r ./resolvers.list -t SOA --output J --outfile "$OUTFILE" --error-log "$OUTERR"  "$INPUT_LIST"
