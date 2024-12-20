#!/bin/bash

#ROM2860A1 Project
if [ "$ROM2860A1" == "true" ]; then
    MODEL_NAME="2860"
    BOARD_VER="A1"
    KERNEL_VERSION="6.6.28"
    CHIP="qcm6490"
    export MODEL_NAME
    export BOARD_VER
    export KERNEL_VERSION
    export CHIP
    ./risc_qcs_linux_yocto_dailybuild_aim38_1.sh rom2860a1
fi

echo "[ADV] All done!"
