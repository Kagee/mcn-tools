#! /bin/bash

# Start by setting up jobdir so we can start logging
YMD="$(date +%F)"
JOBDIR="./jobs/$YMD"
if [ -d "$JOBDIR" ]; then
  read -p "[WARNING] $JOBDIR exists. Do you want to delete? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -r "$JOBDIR"
  fi
fi

mkdir -p "$JOBDIR"

PIPEFILE="$JOBDIR/log.pip"
rm $PIPEFILE 2>/dev/null || true
mkfifo "$PIPEFILE" || exit

# Start tee writing to a logfile, but pulling its input from our named pipe.
tee "$JOBDIR/run.log" < $PIPEFILE &

# capture tee's process ID so we can terminate it at script end
TEEPID=$!

# redirect the rest of the stderr and stdout to our named pipe.
exec > $PIPEFILE 2>&1

source config.sh
source 01-check-tools.sh

if [ -d "$JOBDIR" ]; then
  1>&2 echo "[INFO] Found jobdir: $JOBDIR"
  #rm -r ""
else
  1>&2 echo "[INFO] Creating jobdir: $JOBDIR"
  mkdir -p "$JOBDIR"
fi

INPUT="$(cat 00-make-input.txt)"
echo "$INPUT" > "$JOBDIR/input.txt"
FILES="$(echo "$INPUT" | grep -o -P '[^\s]*\.list')"
NUM_INPUT="$(echo "$FILES" | wc -l)"
1>&2 echo "[INFO] There are $NUM_INPUT input files."
1>&2 echo "[INFO] LINES   SOURCE"
wc -l $(echo "$INPUT" | grep -o -P '[^\s]*\.list') | sed -e 's#/.*/##' | sort -gr | 1>&2 sed -e 's/^/[INFO]/'
CREDITS="$(echo "$INPUT" | grep -F 'Credits:' | sed 's/Credits: *//')"
SOURCES="$(echo "$INPUT" | grep -F 'Source:' | sed -e 's/^Source: \([^ ]*\) .*/\1/' | sort)"
1>&2 echo "[INFO] Current sources: " $SOURCES
echo "$FILES" > "$JOBDIR/files.txt"
echo "$CREDITS" > "$JOBDIR/credits.txt"
echo "$SOURCES" > "$JOBDIR/sources.txt"
echo "$FILES" | xargs -L1 cat | sort > "$JOBDIR/full.list"

# Calculate some pretty stats
1>&2 echo "[INFO] Calculating input statistics..."
cat "$JOBDIR/full.list" | uniq -c | sed 's/^ *//' | sort -g > "$JOBDIR/tmp.list"
INPUT_COUNT="$(wc -l "$JOBDIR/tmp.list" | cut -d ' ' -f 1)"
1>&2 echo "[INFO] There are $INPUT_COUNT input domains"
# ignore domains shorter than 3 chars, as those are probaby permutated
IDN_COUNT="$(grep -P '[^a-z0-9-\. ]' "$JOBDIR/tmp.list" | sed 's/^.* //' | grep -c -P '^.......')"
IDN_NONCOMMON_COUNT="$(grep -P '[^a-zæøå0-9-\. ]' "$JOBDIR/tmp.list" | sed 's/^.* //' | grep -c -P '^.......')"
1>&2 echo "[INFO] There are $IDN_COUNT input domains with a laber longer than 3 that contain non-ascii characters"
1>&2 echo "[INFO] There are $IDN_NONCOMMON_COUNT input domains with a laber longer than 3 that contain non-ascii non-øæå characters"
for I in $(seq 1 $NUM_INPUT ); do
  COUNT="$(grep -c -P "^$I " "$JOBDIR/tmp.list")";
  1>&2 echo "[INFO] $COUNT domains appear in $I sources"
done

function idn_while_loop {
  while read D; do
    # The reason we don't pipe all the data through
    # idn at the same time, is because it dies if
    # it recieves any data it can't parse
    PIDN="$(echo "$D" | idn --no-tld 2>&1)"
    if [ $? -ne 0 ]; then
      1>&2 echo "[ERROR] $D ($PIDN)"
      #exit 1
    else
      echo "$PIDN"
    fi
  done;
}

export -f idn_while_loop

uniq "$JOBDIR/full.list" > "$JOBDIR/full_uniq.list"

1>&2 echo "[INFO] Starting idn normalization. This should take 8-15 minutes during normal load. ($(date --iso=seconds))"
# Using a bash while loop as this is a LOT fater than calling idn directly from parallel
cat "$JOBDIR/full_uniq.list" | parallel \
  --pipe idn_while_loop 2> "$JOBDIR/idn.error" | sort | uniq > "$JOBDIR/full_uniq_post_idn.list"
1>&2 echo "[INFO] Idn normalization complete ($(date --iso=seconds))"
1>&2 echo "[INFO] idn input was $(grep -c '.*' "$JOBDIR/full_uniq.list") domains"
1>&2 echo "[INFO] $(grep -c '.*' "$JOBDIR/idn.error") domains failed idn normalization (see $JOBDIR/idn.error)"
1>&2 echo "[INFO] $(grep -c '.*' "$JOBDIR/full_uniq_post_idn.list") domains remains after idn normalization"

source 03-run-massdns.sh

1>&2 echo "[INFO] massdns run is complete. To re-run, run ./03-run-massdns.sh $JOBDIR"

source 04-compare-to-norid.sh

1>&2 echo "[INFO] Norid comapre is complete. To re-run, run ./04-compare-to-norid.sh $JOBDIR"

# close the stderr and stdout file descriptors.
exec 1>&- 2>&-

# Wait for tee to finish since now that other end of the pipe has closed.
wait $TEEPID
rm "$PIPEFILE" || true
