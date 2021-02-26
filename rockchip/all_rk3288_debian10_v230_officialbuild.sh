#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3288_projects
if [ "$RSB4680A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_rsb4680a3_2G
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-rsb4680-a3.img
	MACHINE_LIST="$MACHINE_LIST rsb_4680"
	MODEL_NAME="4680"
	HW_VER="A3"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3288_debian10_v230_officialbuild.sh $VERSION_NUM
fi


