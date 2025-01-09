#!/bin/bash

#EPCR7300A1_projects
if [ "$epcr7300a1" == "true" ]; then
    PROJECT_BRANCH="epcr7300"
    export PROJECT_BRANCH
    ./risc_nvidia_officialbuild.sh
fi

echo "[ADV] All done!"
