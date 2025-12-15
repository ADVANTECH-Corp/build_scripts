#!/bin/bash

#AOM2721A1 Project
if [ "$aom2721a1" == "true" ]; then
    ./risc_qcs_le_dailybuild.sh
fi

#DS011A1 Project
if [ "$ds011a1" == "true" ]; then
    ./risc_qcs_le_dailybuild.sh
fi

echo "[ADV] All done!"
