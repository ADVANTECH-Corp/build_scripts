#!/bin/bash

#EPCR7300A1_projects
if [ "$EPCR7300A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="7300"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim34.sh EPCR7300A1
fi

#AIR030A1_projects
if [ "$AIR030A1" == "true" ]; then
    IMAGE_TYPE="inner"
    MODEL_NAME="AIR030"
    BOARD_VER="A1"
    DTB="tegra234-air030.dtb"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim34.sh AIR030A1
fi

echo "[ADV] All done!"
