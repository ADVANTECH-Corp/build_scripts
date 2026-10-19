#!/bin/bash
set -e

CSV_FILE="aim_linux_bsp_launcher_v${DAILY_VERSION}_${DAILY_DATE}.csv"
CURR_PATH="${PWD}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DAILY_DATE}"

REPOS=(
    "MTK|https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/MTK"
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

PUSH_NAMES=()
PUSH_REFS=()
CHECK_FAILED=()   # 全部 repo 檢查完才統一報錯

# 發版規則只有一條：正式分支只能 fast-forward 到 daily 快照，且 tag 不可已存在。
# 規則交給 git push 本身判斷（不加 force），先以 --dry-run 檢查所有 repo，全部通過才真正 push。
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

        # 不抓 tag：本地一定能建立 tag，遠端是否已存在交給 push --dry-run 判斷
        rm -rf "$NAME"
        git clone --no-tags "$URL" "$NAME"
        cd "$NAME"

        REFS=""
        for line in $DEVELOP_BRANCHES; do
            BRANCH=$(echo "$line" | cut -d',' -f1)
            COMMIT_HASH=$(echo "$line" | cut -d',' -f2)
            OFFICIAL_BRANCH="${BRANCH%_develop}"
            TAG_NAME="v${OFFICIAL_VERSION}_${OFFICIAL_BRANCH}"
            DEV_TAG_NAME="v${OFFICIAL_VERSION}_${BRANCH}"

            if ! git rev-parse -q --verify "$COMMIT_HASH^{commit}" > /dev/null; then
                CHECK_FAILED+=("$NAME: snapshot commit $COMMIT_HASH of $BRANCH not found")
                continue
            fi

            echo "[INFO] $OFFICIAL_BRANCH -> ${COMMIT_HASH:0:10}, tags $TAG_NAME / $DEV_TAG_NAME"
            git tag -a "$TAG_NAME" "$COMMIT_HASH" -m "Official release $TAG_NAME"
            git tag -a "$DEV_TAG_NAME" "$COMMIT_HASH" -m "Develop snapshot for $TAG_NAME"
            REFS+=" $COMMIT_HASH:refs/heads/$OFFICIAL_BRANCH refs/tags/$TAG_NAME refs/tags/$DEV_TAG_NAME"
        done

        if [ -z "$REFS" ]; then
            cd ..
            continue
        fi

        # === dry-run：由 git 判斷 non-fast-forward / tag already exists ===
        if ! RESULT=$(git push --dry-run --porcelain origin $REFS 2>&1); then
            FAILED_BEFORE=${#CHECK_FAILED[@]}
            while IFS=$'\t' read -r FLAG REF SUMMARY; do
                [ "$FLAG" = "!" ] || continue
                DST="${REF#*:}"
                CHECK_FAILED+=("$NAME: ${DST#refs/*/} $SUMMARY")
                # 診斷資訊：列出正式分支上不在快照裡的 commit
                if [[ "$DST" == refs/heads/* ]]; then
                    echo "[CHECK][ERROR] $NAME ${DST#refs/heads/} $SUMMARY, commits not in snapshot:"
                    git log --format='    %h %ad %an %s' --date=short "${REF%%:*}..origin/${DST#refs/heads/}"
                fi
            done <<< "$RESULT"
            # 非 ref 層級的失敗（權限、網路等）
            if [ ${#CHECK_FAILED[@]} -eq "$FAILED_BEFORE" ]; then
                echo "$RESULT"
                CHECK_FAILED+=("$NAME: dry-run push failed (see log above)")
            fi
        fi

        PUSH_NAMES+=("$NAME")
        PUSH_REFS+=("$REFS")

        cd ..
        echo "=================================================="
    done

    if [ ${#CHECK_FAILED[@]} -gt 0 ]; then
        echo "[ERROR] ${#CHECK_FAILED[@]} check(s) failed. Nothing pushed:"
        printf '  - %s\n' "${CHECK_FAILED[@]}"
        exit 1
    fi
}

# === 所有 repo 都通過 dry-run 才 push，避免中途失敗只推一半 ===
function push_repos() {
    for i in "${!PUSH_NAMES[@]}"; do
        NAME="${PUSH_NAMES[$i]}"
        echo "[PUSH] $NAME:${PUSH_REFS[$i]}"
        git -C "$NAME" push --atomic origin ${PUSH_REFS[$i]}
    done
    echo "[PUSH] All repos pushed."
    echo "=================================================="
}

# === 函數: 產生 release notes（與上一版 official 比較）到產出目錄 ===
function generate_release_notes() {
    python3 "${SCRIPT_DIR}/gen_release_notes.py" \
        --csv "$CSV_FILE" \
        --version "$OFFICIAL_VERSION" \
        --daily-version "$DAILY_VERSION" \
        --daily-date "$DAILY_DATE" \
        --output "${OUTPUT_DIR}/aim_linux_bsp_launcher_v${OFFICIAL_VERSION}_${DAILY_DATE}_release_notes.txt"
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

process_repos
generate_release_notes
push_repos
prepend_official_version_to_csv "$CSV_FILE" "v${OFFICIAL_VERSION}"
prepare_official_package "$DAILY_VERSION" "$DAILY_DATE" "$OFFICIAL_VERSION"
copy_official_files "$OFFICIAL_VERSION" "$DAILY_DATE"

echo "[DONE] Official build v$OFFICIAL_VERSION complete!"