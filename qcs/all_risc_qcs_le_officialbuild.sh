#!/bin/bash

#AOM2721A1 Project
if [ "$aom2721a1" == "true" ]; then
    ./risc_qcs_le_officialbuild.sh
fi

#DS011A1 Project
if [ "$ds011a1" == "true" ]; then
    ./risc_qcs_le_officialbuild.sh
fi

echo "[ADV] All done!"
