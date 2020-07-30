#!/bin/bash
MACHINE_LIST=""
#rk_BSP
./rk_android_N7_dailybuild.sh rk $VERSION_NUM

#DS100_projects
if [ "$DS100" == "true" ]; then
	KERNEL_DTB=rk3399-ds100.img
	KERNEL_CONFIG=rockchip_ds100_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh ds100 $VERSION_NUM
fi
#DS100Lite_projects
if [ "$DS100L" == "true" ]; then
	KERNEL_DTB=rk3399-ds100l.img
	KERNEL_CONFIG=rockchip_ds100l_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100l"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh ds100l $VERSION_NUM
fi
#DS211_projects
if [ "$DS211" == "true" ]; then
        KERNEL_DTB=rk3399-ds211.img
        KERNEL_CONFIG=rockchip_ds211_defconfig
        MACHINE_LIST="$MACHINE_LIST ds211"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh ds211 $VERSION_NUM
fi
#DS211_NO_HDMIIN_projects
if [ "$DS211_NO_HDMIIN" == "true" ]; then
        KERNEL_DTB=rk3399-ds211_no_isp.img
        KERNEL_CONFIG=rockchip_ds211_defconfig
        MACHINE_LIST="$MACHINE_LIST ds211"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh ds211 $VERSION_NUM
fi
#DS100_DeviceOn_projects
if [ "$DS100_DeviceOn" == "true" ]; then
	KERNEL_DTB=rk3399-ds100.img
	KERNEL_CONFIG=rockchip_ds100_defconfig
	MACHINE_LIST="$MACHINE_LIST ds100_DeviceOn"
export KERNEL_DTB
export KERNEL_CONFIG
export MACHINE_LIST
./rk_android_N7_dailybuild.sh ds100_DeviceOn $VERSION_NUM
fi
echo "[ADV] All done!"


