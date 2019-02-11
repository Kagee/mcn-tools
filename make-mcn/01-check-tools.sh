#! /bin/bash
function has {
  command -v $1 >/dev/null && echo "[INFO] Found $1" || { echo "[ERROR] Didn't find $1, please install"; exit 1; }
}
has git
has idn

if [ ! -d "./massdns" ]; then
  git clone https://github.com/blechschmidt/massdns.git
else
  cd ./massdns && git pull 1>/dev/null
fi
# Hacky compile-only-if-new, since massdns has a sub-optimal Makefile
find . ! -path '*.git*'  -newer bin/massdns | egrep '.*' >/dev/null && make
cd ..
if [ -f massdns/bin/massdns ]; then
  echo "[INFO] Found massdns"
else
   echo "[ERROR] Didn't find $1, please check source"; exit 1;
fi
