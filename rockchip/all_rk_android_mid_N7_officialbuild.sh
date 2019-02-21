#!/bin/bash
MACHINE_LIST=""

#DS100_projects
if [ "$DS100" == "true" ]; then
	KERNEL_DTB=rk3399-ds100.img
	KERNEL_CONFIG=rockchip_ds100_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100"
	export KERNEL_DTB
	export KERNEL_CONFIG
	export MACHINE_LIST
	./rk_android_mid_N7_officialbuild.sh $VERSION_NUM
	[ "$?" -ne 0 ] && exit 1
fi
#DS100Lite_projects
if [ "$DS100L" == "true" ]; then
	KERNEL_DTB=rk3399-ds100l.img
	KERNEL_CONFIG=rockchip_ds100l_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100l"
	export KERNEL_DTB
	export KERNEL_CONFIG
	export MACHINE_LIST
	./rk_android_mid_N7_officialbuild.sh $VERSION_NUM
	[ "$?" -ne 0 ] && exit 1
fi
echo "[ADV] All done!"
