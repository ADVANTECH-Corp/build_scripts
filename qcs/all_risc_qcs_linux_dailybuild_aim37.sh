#!/bin/bash

#ROM2860A1 Project
if [ "$ROM2860A1" == "true" ]; then
    MODEL_NAME="2860"
    BOARD_VER="A1"
    export MODEL_NAME
    export BOARD_VER
    ./risc_qcs_linux_dailybuild_aim37.sh ROM2860A1
fi

echo "[ADV] All done!"
