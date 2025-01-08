#!/bin/bash

#EPCR7300A1_projects
if [ "$epcr7300a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

echo "[ADV] All done!"
