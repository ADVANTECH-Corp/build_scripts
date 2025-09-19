#!/bin/bash

#AIR030A1_projects
if [ "$air030a1" == "true" ]; then
    PROJECT_BRANCH="air030"
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#EPCR7300A1_projects
if [ "$epcr7300a1" == "true" ]; then
    PROJECT_BRANCH="epcr7300"
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#AFER750A1_projects
if [ "$afer750a1" == "true" ]; then
    PROJECT_BRANCH="afer750"
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#AIR020RA1_projects
if [ "$air020ra1" == "true" ]; then
    PROJECT_BRANCH="air020r"
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#EBCRC04A1_projects
if [ "$ebcrc04a1" == "true" ]; then
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#DS015A1_projects
if [ "$ds015a1" == "true" ]; then
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

#AIR021A1_projects
if [ "$air021a1" == "true" ]; then
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

echo "[ADV] All done!"
