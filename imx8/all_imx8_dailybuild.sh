#!/bin/bash
MACHINE_LIST=""
#imx8_projects
if [ $ROM7720A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx8qmrom7720a1"
fi
export MACHINE_LIST
./imx8_dailybuild.sh
