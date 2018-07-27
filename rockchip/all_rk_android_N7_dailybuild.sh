#!/bin/bash
MACHINE_LIST=""

#DS100_projects
if [ "$DS100" == "true" ]; then
	KERNEL_DTB=rk3399-ds100.img
	KERNEL_CONFIG=rockchip_ds100_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100"
fi
#DS100Lite_projects
if [ "$DS100L" == "true" ]; then
	KERNEL_DTB=rk3399-ds100l.img
	KERNEL_CONFIG=rockchip_ds100l_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100l"
fi

export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh $VERSION_NUM
