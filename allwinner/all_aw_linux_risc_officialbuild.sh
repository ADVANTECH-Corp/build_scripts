#!/bin/bash

PROJECT_LIST=""

#T536_projects

if [ "${AFEE620}" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST AFE-E620"
	PLATFORM_AW="arm64"
	OS_BUILD_ROOTFS=${ROOTFS_AW}
	PROJECT="afe-e620"
	BOARD_CONFIG_AW="linux-5.15-origin"
	RT_PATCH="false"

	export PROJECT_LIST
	export PLATFORM_AW
	export OS_BUILD_ROOTFS
	export PROJECT
	export BOARD_CONFIG_AW

	./aw_t536_linux_risc_officialbuild.sh
fi
