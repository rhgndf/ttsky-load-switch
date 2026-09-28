#!/bin/bash
# usage: ./run_corners.sh  (run inside the eda container)
cd "$(dirname "$0")"
for c in tt ss ff sf fs; do for t in -40 27 85; do for v in 3.0 3.3 3.6; do for r in 0.8 0.05; do
  f=corner_${c}_${t}_${v}_${r}
  sed -e "s/CORNER/$c/" -e "s/TEMP/$t/" -e "s/VAP/$v/" -e "s/RSHORT/$r/" tb_corner.spice > $f.spice
  echo "$c T=$t VAPWR=$v Rov=$r $(ngspice -b $f.spice 2>&1 | grep -E '^(ipk|ilim|ipp|ctv|ilimf) ' | awk '{printf "%s=%s ",$1,$3}')" &
  while [ $(jobs -r | wc -l) -ge 8 ]; do sleep 1; done
done; done; done; done; wait
rm -f corner_*.spice
