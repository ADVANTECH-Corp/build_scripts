#!/bin/bash

#EPCR7300A1_projects
if [ "$EPCR7300A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="7300"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim35.sh EPCR7300A1
fi

#EPCR7200A1_projects
if [ "$EPCR7200A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="7200"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim35.sh EPCR7200A1
fi

#AIR030A1_projects
if [ "$AIR030A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="AIR030"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim35.sh AIR030A1
fi

#AIR020A1_projects
if [ "$AIR020A1" == "true" ]; then
    IMAGE_TYPE="external"
    MODEL_NAME="AIR020"
    BOARD_VER="A1"
    export IMAGE_TYPE
    export MODEL_NAME
    export BOARD_VER
    ./risc_nvidia_jetson_dailybuild_aim35.sh AIR020A1
fi

echo "[ADV] All done!"
