#!/bin/bash
MACHINE_LIST=""
#imx8_projects
if [ $IMX8MQ == true ]; then
        MACHINE_LIST="$MACHINE_LIST imx8mqevk"
fi
export MACHINE_LIST
./imx8_sumo_dailybuild.sh
