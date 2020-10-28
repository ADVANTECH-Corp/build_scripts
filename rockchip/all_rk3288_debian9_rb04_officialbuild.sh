#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3288_projects
if [ "$EBCRB04A2" == "true" ]; then
	UBOOT_DEFCONFIG=ebcrb04a2-2G-rk3288
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-ebcrb04-a2.img
	MACHINE_LIST="$MACHINE_LIST ebcrb04"
	MODEL_NAME="RB04"
	HW_VER="A2"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3288_debian9_rb04_officialbuild.sh $VERSION_NUM
fi

