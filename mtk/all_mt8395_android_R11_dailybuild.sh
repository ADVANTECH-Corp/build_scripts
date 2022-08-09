#!/bin/bash
MACHINE_LIST=""

#Get mtk android source code from git
./mt8395_android_R11_dailybuild.sh mtk

#RSB3810A1_projects
if [ "$RSB3810A1" == "true" ]; then
    KERNEL_DTB=
    KERNEL_CONFIG=
    LUNCH_COMBO="full_mt8395_rsb3810a1-userdebug"
    OUTPUT_FOLDER="mt8395_rsb3810a1"
    MACHINE_LIST="$MACHINE_LIST RSB3810A1"
    MODEL_NAME="3810"
    BOARD_VER="A1"
    export KERNEL_DTB
    export KERNEL_CONFIG
    export LUNCH_COMBO
    export OUTPUT_FOLDER
    export MACHINE_LIST
    export MODEL_NAME
    export BOARD_VER
    ./mt8395_android_R11_dailybuild.sh RSB3810A1
fi

echo "[ADV] All done!"
