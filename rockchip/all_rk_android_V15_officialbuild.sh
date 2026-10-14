#!/bin/bash

MACHINE_LIST=""

#rk3576_projects
if [ "$AOM3841A1" == "true" ]; then
        UBOOT_DEFCONFIG=rk3576_aom3841a1
        KERNEL_DEFCONFIG=rk3576_adv_defconfig
        KERNEL_DTB=rk3576-aom3841-a1.img
        ANDROID_PRODUCT=aom3841_u-ap4a-userdebug
        PROJECT_NAME=aom3841a1
        MACHINE_LIST="$MACHINE_LIST aom3841"

        export UBOOT_DEFCONFIG
        export KERNEL_DEFCONFIG
        export KERNEL_DTB
        export ANDROID_PRODUCT
        export MACHINE_LIST
        export PROJECT_NAME
        ./rk_android_V15_officialbuild.sh
fi

if [ "$AOM5841A1" == "true" ]; then
        UBOOT_DEFCONFIG=rk3576_aom5841a1
        KERNEL_DEFCONFIG=rk3576_adv_defconfig
        KERNEL_DTB=rk3576-aom5841-a1.img
        ANDROID_PRODUCT=aom5841_u-ap4a-userdebug
        PROJECT_NAME=aom5841a1
        MACHINE_LIST="$MACHINE_LIST aom5841"

        export UBOOT_DEFCONFIG
        export KERNEL_DEFCONFIG
        export KERNEL_DTB
        export ANDROID_PRODUCT
        export MACHINE_LIST
        export PROJECT_NAME
        ./rk_android_V15_officialbuild.sh
fi
