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
./rk3399_debian9_v210_officialbuild.sh $VERSION_NUM
fi
#DS100Lite_projects
if [ "$DS100L" == "true" ]; then
	KERNEL_DTB=rk3399-ds100l.img
	KERNEL_CONFIG=rockchip_ds100l_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100l"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk3399_debian9_v210_officialbuild.sh $VERSION_NUM
fi
#DMSSA53_projects
if [ "$DMSSA53" == "true" ]; then
	KERNEL_DTB=rk3399-dmssa53.img
	KERNEL_CONFIG=rockchip_dmssa53_defconfig
	MACHINE_LIST="$MACHINE_LIST dmssa53"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk3399_debian9_v210_officialbuild.sh $VERSION_NUM
fi
echo "[ADV] All done!"


