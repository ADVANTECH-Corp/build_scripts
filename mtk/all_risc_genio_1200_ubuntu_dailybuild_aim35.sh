#!/bin/bash

#RSB3810A1 Project
if [ "$RSB3810A1" == "true" ]; then
    MODEL_NAME="3810"
    BOARD_VER="A1"
    export MODEL_NAME
    export BOARD_VER
    ./risc_genio_1200_ubuntu_dailybuild_aim35.sh RSB3810A1
fi

echo "[ADV] All done!"
