#!/bin/bash
MACHINE_LIST=""
#rk_BSP
./rk_github_buildroot_dailybuild.sh rk $VERSION_NUM

if [ "$DS100" == "true" ]; then
	KERNEL_DTB=rk3399-ds100.img
	KERNEL_CONFIG=rockchip_ds100_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_github_buildroot_dailybuild.sh ds100 $VERSION_NUM
fi
echo "[ADV] All done!"


