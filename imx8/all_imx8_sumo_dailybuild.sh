#!/bin/bash
MACHINE_LIST=""
#imx8_projects
[[ $ROM7720A1 == true ]] && MACHINE_LIST="$MACHINE_LIST imx8qmrom7720a1"
[[ $ROM5720A1 == true ]] && MACHINE_LIST="$MACHINE_LIST imx8mqrom5720a1"
[[ $ROM5620A1 == true ]] && MACHINE_LIST="$MACHINE_LIST imx8qxprom5620a1"

export MACHINE_LIST
./imx8_sumo_dailybuild.sh
