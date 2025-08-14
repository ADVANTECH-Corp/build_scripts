#!/bin/bash

#EPCR7300A1_projects
if [ "$epcr7300a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#AFER750A1_projects
if [ "$afer750a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#AIR020RA1_projects
if [ "$air020ra1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#EBCRC04A1_projects
if [ "$ebcrc04a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#DS015A1_projects
if [ "$ds015a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

#AIR021A1_projects
if [ "$air021a1" == "true" ]; then
    ./risc_nvidia_dailybuild.sh
fi

echo "[ADV] All done!"
