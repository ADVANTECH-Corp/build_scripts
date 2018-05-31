#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

#rk3288_projects
if [ "$RSB4680A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_rsb4680a3_2G_defconfig
	KERNEL_DTB=rk3288-rsb4680-a3.img
	ANDROID_CONFIG=rsb4680-userdebug
fi

export UBOOT_DEFCONFIG
export KERNEL_DTB
export ANDROID_CONFIG
./rk_android_M6_officialbuild.sh $VERSION_NUM

