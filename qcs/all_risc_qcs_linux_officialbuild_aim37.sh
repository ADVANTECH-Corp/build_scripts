#!/bin/bash
VER_PREFIX="qcs"
export VER_PREFIX

#ROM2860A1 Project
if [ "$ROM2860A1" == "true" ]; then
    MODEL_NAME="2860"
    BOARD_VER="A1"
    TARGET_BOARD="rom2860-a1"
    KERNEL_BRANCH="adv_5.4.r71-rel"
    export MODEL_NAME
    export BOARD_VER
    export TARGET_BOARD
    export KERNEL_BRANCH
    ./risc_qcs_linux_officialbuild_aim37.sh ROM2860A1
fi

echo "[ADV] All done!"
