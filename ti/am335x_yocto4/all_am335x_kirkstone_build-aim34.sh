#!/bin/bash

function build_project()
{
	echo "[ADV] $1 start"

		# Dailybuild
		BUILD_SH="./am335x_kirkstone_build-aim34.sh"

#am335x_projects
	if [ $EPCR3220A1 == true ]; then
		$BUILD_SH am335xepcr3220a1
		[ "$?" -ne 0 ] && exit 1
	fi
}

build_project

echo "[ADV] All done!"
