#!/bin/bash

PROJECT_LIST=""

if [ "$EBCRS20A1" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST EBCRS20"
	PROJECT="ebcrs20a1"

	export PROJECT_LIST
	export PROJECT
	./imx8_debian13_officialbuild.sh
fi

