#!/bin/bash
set -e

CSV_FILE="aim_linux_bsp_launcher_v${DAILY_VERSION}_${DAILY_DATE}.csv"
CURR_PATH="${PWD}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DAILY_DATE}"

REPOS=(
    "NXP|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/NXP"
    "NVIDIA|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/NVIDIA"
    "Qualcomm|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/Qualcomm"
    "Rockchip|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/Rockchip"
    "AIM_Linux_BSP_Launcher|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/AIM_Linux_BSP_Launcher"
)

echo "[OFFICIAL] DailyBuildVersion = ${DAILY_VERSION}"
echo "[OFFICIAL] DailyDate = $DAILY_DATE"
echo "[OFFICIAL] OfficialVersion = $OFFICIAL_VERSION"
echo "[OFFICIAL] Using CSV file: $CSV_FILE"

if [ ! -f "$CSV_FILE" ]; then
    echo "[ERROR] CSV file $CSV_FILE not found!"
    exit 1
fi

# ===========
# Functions
# ===========

function check_existing_tags() {
    for entry in "${REPOS[@]}"; do
        NAME="${entry%%|*}"
        URL="${entry##*|}"

        echo "[CHECK] Checking tags in $NAME ..."
        git ls-remote --tags "$URL" | grep -q "refs/tags/v${OFFICIAL_VERSION}$" && {
            echo "[ERROR] Tag v${OFFICIAL_VERSION} already exists in $NAME!"
            exit 1
        }
        git ls-remote --tags "$URL" | grep -q "refs/tags/v${OFFICIAL_VERSION}_develop$" && {
            echo "[ERROR] Tag v${OFFICIAL_VERSION}_develop already exists in $NAME!"
            exit 1
        }
    done
    echo "[CHECK] No existing tags found. Proceeding ..."
    echo "=================================================="
}

function process_repos() {
    for entry in "${REPOS[@]}"; do
        NAME="${entry%%|*}"
        URL="${entry##*|}"

        echo "[INFO] Processing $NAME ($URL)"

        DEVELOP_BRANCHES=$(awk -F',' -v platform="$NAME" '$1==platform && $2 ~ /_develop/ {print $2","$3}' "$CSV_FILE")
        if [ -z "$DEVELOP_BRANCHES" ]; then
            echo "[WARN] No _develop branches found for $NAME in CSV."
            continue
        fi

        rm -rf "$NAME"
        git clone "$URL" "$NAME"
        cd "$NAME"

        # 這裡要確保所有 remote branch 都抓下來
        git fetch --all --tags

        for line in $DEVELOP_BRANCHES; do
            BRANCH=$(echo "$line" | cut -d',' -f1)
            COMMIT_HASH=$(echo "$line" | cut -d',' -f2)
            OFFICIAL_BRANCH="${BRANCH%_develop}"

            echo "[INFO] Found develop branch: $BRANCH"
            echo "[INFO] Commit hash to rebase until: $COMMIT_HASH"
            echo "[INFO] Target official branch: $OFFICIAL_BRANCH"

            # === official branch rebase ===
            git fetch origin "$OFFICIAL_BRANCH" || true
            git checkout -B "$OFFICIAL_BRANCH" "origin/$OFFICIAL_BRANCH"
            git pull origin "$OFFICIAL_BRANCH"

            MERGE_BASE=$(git merge-base "$OFFICIAL_BRANCH" "origin/$BRANCH")
            echo "[INFO] Merge-base between $OFFICIAL_BRANCH and $BRANCH is $MERGE_BASE"

            git checkout -B tmp_rebase_branch "$COMMIT_HASH"
            echo "[INFO] Rebasing commits from $MERGE_BASE..$COMMIT_HASH onto $OFFICIAL_BRANCH ..."
            git rebase --onto "$OFFICIAL_BRANCH" "$MERGE_BASE"

            git checkout "$OFFICIAL_BRANCH"
            git merge --ff-only tmp_rebase_branch || true
            git push origin "$OFFICIAL_BRANCH"

            # === tag on official branch ===
            echo "[INFO] Tagging $OFFICIAL_BRANCH with v$OFFICIAL_VERSION ..."
            git tag -a "v$OFFICIAL_VERSION" -m "Official release v$OFFICIAL_VERSION"
            git push origin "v$OFFICIAL_VERSION"

            # === tag on develop branch ===
            echo "[INFO] Tagging $BRANCH with v${OFFICIAL_VERSION}_develop at commit $COMMIT_HASH ..."
            git checkout -B "$BRANCH" "origin/$BRANCH"
            git tag -a "v${OFFICIAL_VERSION}_develop" "$COMMIT_HASH" -m "Develop snapshot for v$OFFICIAL_VERSION"
            git push origin "v${OFFICIAL_VERSION}_develop"
        done

        cd ..
        echo "=================================================="
    done
}

# === 函數: prepend OfficialVersion 到 CSV ===
function prepend_official_version_to_csv() {
    local csv_file="$1"
    local official_version="$2"

    if [ ! -f "$csv_file" ]; then
        echo "[ERROR] CSV file $csv_file not found!"
        exit 1
    fi

    {
        echo "OfficialVersion"
        echo "$official_version"
        echo ""
        cat "$csv_file"
    } > "${csv_file}.tmp"

    mv "${csv_file}.tmp" "$csv_file"
    echo "[INFO] OfficialVersion $official_version prepended to $csv_file"
}

# === 函數：準備官方 package ===
function prepare_official_package() {
    local daily_version=$1
    local daily_date=$2
    local official_version=$3

    local base_name="aim_linux_bsp_launcher_v${daily_version}_${daily_date}"
    local official_base="aim_linux_bsp_launcher_v${official_version}_${daily_date}"

    echo "[INFO] Extracting ${base_name}.tgz..."
    tar -xzf "${base_name}.tgz"
    mv "${base_name}" "${official_base}"

    echo "[INFO] Creating ${official_base}.tgz..."
    tar -czf "${official_base}.tgz" "${official_base}"

    echo "[INFO] Generating md5 for ${official_base}.tgz..."
    md5sum "${official_base}.tgz" | awk '{print $1}' > "${official_base}.tgz.md5"

    echo "[INFO] Renaming CSV file..."
    mv "${base_name}.csv" "${official_base}.csv"

    echo "[INFO] Generating md5 for ${official_base}.csv..."
    md5sum "${official_base}.csv" | awk '{print $1}' > "${official_base}.csv.md5"

    echo "[DONE] Official package prepared: ${official_base}.tgz and ${official_base}.csv"
}

function copy_official_files() {
    local version=$1
    local date=$2
    local base_name="aim_linux_bsp_launcher_v${version}_${date}"

    # 拷貝所有相關檔案
    cp -v ${base_name}.* "${OUTPUT_DIR}/"

    echo "[INFO] All official files copied to ${OUTPUT_DIR}/"
}

# ===========
# Main
# ===========

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
	echo "[ADV] $OUTPUT_DIR had already been created"
else
	echo "[ADV] mkdir $OUTPUT_DIR"
	mkdir -p $OUTPUT_DIR
fi

check_existing_tags
process_repos
prepend_official_version_to_csv "$CSV_FILE" "v${OFFICIAL_VERSION}"
prepare_official_package "$DAILY_VERSION" "$DAILY_DATE" "$OFFICIAL_VERSION"
copy_official_files "$OFFICIAL_VERSION" "$DAILY_DATE"

echo "[DONE] Official build v$OFFICIAL_VERSION complete!"
