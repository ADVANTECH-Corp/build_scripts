#!/bin/bash

#AOM2721A1 Project
if [ "$aom2721a1" == "true" ]; then
    CHIP="qcm6490"
    export CHIP
    ./risc_qcs_le_dailybuild.sh
fi

echo "[ADV] All done!"
