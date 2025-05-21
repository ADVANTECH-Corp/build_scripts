#!/bin/bash

MACHINE_LIST=""

#rk3568_projects
if [ "$rk3568" == "true" ]; then
	openharmony_PRODUCT=rk3568
	MACHINE_LIST="$MACHINE_LIST rk3568"

	export openharmony_PRODUCT
	export MACHINE_LIST
	./openharmony_5.0_officialbuild.sh
fi
