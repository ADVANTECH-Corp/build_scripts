#!/bin/bash
VER_PREFIX="qcs"
export VER_PREFIX

#ROM2860A1 Project
if [ "$ROM2860A1" == "true" ]; then
    MODEL_NAME="2860"
    BOARD_VER="A1"
    TARGET_BOARD="rom2860-a1"
    export MODEL_NAME
    export BOARD_VER
    export TARGET_BOARD
    ./risc_qcs_linux_yocto_officialbuild_aim38_1.sh rom2860a1
fi

echo "[ADV] All done!"
