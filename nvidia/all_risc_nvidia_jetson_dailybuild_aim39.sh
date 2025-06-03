#!/bin/bash

#AFER750A1_projects
if [ "$AFER750A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="R750"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim39.sh AFER750A1
fi

echo "[ADV] All done!"
