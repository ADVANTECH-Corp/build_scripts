#!/bin/bash

#EPCR7300A1_projects
if [ "$epcr7300a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#AFER750A1_projects
if [ "$afer750a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

echo "[ADV] All done!"
