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
1>&2 echo "[INFO] zdns input list is $INPUT_LIST"
# TODO: Shuffle massdns input
MINUTE="$(date +%F-%H-%M)"
OUTFILE="$JOBDIR/result_SOA.${MINUTE}.json"
OUTERR="$JOBDIR/result_SOA.${MINUTE}.log"
1>&2 echo "[INFO] zdns output file is $OUTFILE"
#$MD -r ./resolvers.list -t SOA --output J --outfile "$OUTFILE" --error-log "$OUTERR"  "$INPUT_LIST"
$HOME/go/src/github.com/Kagee/zdns/zdns/zdns SOA -iterative -input-file "$INPUT_LIST" -log-file "$OUTERR" -output-file "$OUTFILE"
