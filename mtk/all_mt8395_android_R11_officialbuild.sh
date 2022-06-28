#!/bin/bash
VER_PREFIX="mt8395"
BSP_BRANCH="adv_alps-release-r0.mp6-aiot-V1.81"
PRELOADER_BRANCH="adv_alps-release-r0.mp6-aiot-V1.81"
LK_BRANCH="adv_alps-release-r0.mp6-aiot-V1.81"
DEVICE_BRANCH="adv_alps-release-r0.mp6-aiot-V1.81"
KERNEL_BRANCH="adv_4.19_alps-release-r0.mp6-aiot-V1.81"

export VER_PREFIX
export BSP_BRANCH
export PRELOADER_BRANCH
export LK_BRANCH
export DEVICE_BRANCH
export KERNEL_BRANCH

#RSB3810A1_projects
if [ "$RSB3810A1" == "true" ]; then
    MODEL_NAME="3810"
    BOARD_VER="A1"
    export MODEL_NAME
    export BOARD_VER
    ./mt8395_android_R11_officialbuild.sh
    [ "$?" -ne 0 ] && exit 1
fi

echo "[ADV] All done!"
