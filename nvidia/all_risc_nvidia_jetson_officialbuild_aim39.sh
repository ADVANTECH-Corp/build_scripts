#!/bin/bash
VER_PREFIX="nv"
export VER_PREFIX

#AFER750A1_projects
if [ "$AFER750A1" == "true" ]; then
    MODEL_NAME="R750"
    BOARD_VER="A1"
    TARGET_BOARD="jetson-afer750-a1"
    PROJECT_BRANCH="afer750"
    export MODEL_NAME
    export BOARD_VER
    export TARGET_BOARD
    export PROJECT_BRANCH
    ./risc_nvidia_jetson_officialbuild_aim39.sh AFER750A1
fi

echo "[ADV] All done!"
