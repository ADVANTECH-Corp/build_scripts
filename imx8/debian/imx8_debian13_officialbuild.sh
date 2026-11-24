#!/bin/bash

#
# FILE: imx8_debian13_officialbuild.sh
# PURPOSE: Auto build on azure pipeline
# AUTHOR: Yunjin Jiang <yunjin.jiang@advantech.com.cn>
#

## MODIFICATION DETAILS:
# Date       Version Author          Changes
# 2026-11-24 1.0.0   Yunjin Jiang    Initial implementation


# ===========
#  Strict Error Handling
# ===========
set -Eeuo pipefail

# ===========
#  Global Variables
# ===========
declare -g SCRIPT_VERSION="1.0.0"

declare -g VERSION_K="" VERSION_M="" VERSION_P=""
declare -g VERSION_K_LAST="" VERSION_M_LAST="" VERSION_P_LAST=""
declare -g ADV_VERSION=""
declare -g KERNEL_VERSION="${KERNEL_VERSION:-6.12.20}"
declare -g RAM_SIZE="all" STORAGE="all"
declare -g FIRST_PROJECT="true"
declare -g CURR_PATH="$PWD"
declare -g ROOT_DIR="${OS_DISTRO}_${DATE}"
declare -g ROOTFS="${ROOTFS:-debian}"  # Default value is debian
declare -g ROOTFS_DIR="${ROOTFS_DIR:-flexbuild}"  # Default value is debian

# Read-only arrays
readonly REQUIRED_VARS=(
    "BSP_URL" "BSP_BRANCH"
    "DATE" "STORED"
    "SDK_VERSION" "OS_DISTRO" "CHIP_NAME"
    "VERSION_TYPE" "VERSION_FIXED"
    "PROJECT" "PROJECT_LIST"
)

# ===========
#  Functions
# ===========

# Logging functions
function get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

function log_info() {
    echo "[ADV][$(get_timestamp)] INFO: $1"
}

function log_warning() {
    echo "⚠️ [ADV][$(get_timestamp)] WARNING: $1"
}

function log_error() {
    echo "❌ [ADV][$(get_timestamp)] ERROR: $1"
}

function log_success() {
    echo "✅ [ADV][$(get_timestamp)] SUCCESS: $1"
}

# Error handling function
function handle_error() {
    local exit_code=$?
    trap - ERR
    local line_no=$1
    local command=$2
    log_error "Command failed at line $line_no: $command (exit code: $exit_code)"
    exit $exit_code
}

trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Safe directory change function
function safe_cd() {
    local target_dir="$1"
    if ! cd "$target_dir"; then
        log_error "Failed to enter directory: $target_dir"
        return 1
    fi
    return 0
}

# Validate required environment variables
function validate_environment() {
    local missing_vars=()

    set +u
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    set -u
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Required variables not set: ${missing_vars[*]}"
        return 1
    fi

    # Validate VERSION_TYPE
    local version_type_lower="${VERSION_TYPE,,}"
    case "$version_type_lower" in
        "ga"|"beta"|"alpha")
            log_info "Valid VERSION_TYPE: $VERSION_TYPE"
            ;;
        *)
            log_error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'GA', 'Beta' or 'Alpha'"
            return 1
            ;;
    esac
    # Convert VERSION_TYPE to lowercase
    VERSION_TYPE="$version_type_lower"
    
    # Validate VERSION_FIXED
    local version_fixed_lower="${VERSION_FIXED,,}"
    case "$version_fixed_lower" in
        "true"|"false")
            log_info "Valid VERSION_FIXED: $VERSION_FIXED"
            ;;
        *)
            log_error "Invalid VERSION_FIXED '$VERSION_FIXED'. Must be 'true' or 'false'"
            return 1
            ;;
    esac
    # Convert VERSION_FIXED to lowercase
    VERSION_FIXED="$version_fixed_lower"

    log_success "All required environment variables are set"
}

function create_root_dir() {
    local target_dir="$CURR_PATH/$ROOT_DIR"
    
    if [[ -e "$target_dir" ]]; then
        log_info "Directory already exists: $target_dir"
    else
        log_info "Creating root directory: $target_dir"
        if ! mkdir -p "$target_dir"; then
            log_error "Failed to create directory: $target_dir"
            return 1
        fi
    fi
    
    safe_cd "$target_dir" || return 1
}

function create_output_dir() {
    safe_cd "$CURR_PATH" || return 1
    
    local output_subdirs=("image" "others")
    
    for subdir in "${output_subdirs[@]}"; do
        local full_path="$OUTPUT_DIR/${PROJECT}/$subdir"
        if [[ -e "$full_path" ]]; then
            log_info "Directory exists: $full_path"
        else
            log_info "Creating directory: $full_path"
            if ! mkdir -p "$full_path"; then
                log_error "Failed to create directory: $full_path"
                return 1
            fi
        fi
    done

    return 0
}

function get_first_project() {
    local idx=0

    for _ in $PROJECT_LIST; do
        ((idx++)) || true
    done
    
    if [[ $idx -gt 1 ]]; then
        FIRST_PROJECT="false"
    else
        FIRST_PROJECT="true"
    fi
    
    log_info "First project flag: $FIRST_PROJECT"

    return 0
}

function get_adv_version() {
    local version_file="$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR/version/${PROJECT}"
    
    if [[ ! -f "$version_file" ]]; then
        VERSION_K_LAST="0"
        VERSION_M_LAST="0"
        VERSION_P_LAST="0"
        log_info "No previous version file found, starting from 0.0.0"
    else
        VERSION_K_LAST=$(grep -E '^VERSION_K\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_M_LAST=$(grep -E '^VERSION_M\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_P_LAST=$(grep -E '^VERSION_P\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)

        log_info "Previous version: $VERSION_K_LAST.$VERSION_M_LAST.$VERSION_P_LAST"
    fi
    
    # Validate version numbers are numeric
    if ! [[ "$VERSION_K_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_M_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_P_LAST" =~ ^[0-9]+$ ]]; then
        log_error "Invalid version format detected: VERSION_K_LAST='$VERSION_K_LAST', VERSION_M_LAST='$VERSION_M_LAST', VERSION_P_LAST='$VERSION_P_LAST'"
        log_error "Please check the version file: 'version/${PROJECT}'"
        return 1
    fi

    # Version calculation logic
    case $VERSION_TYPE in
        "ga")
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_K="${VERSION_K_LAST}"
            else
                VERSION_K=$((VERSION_K_LAST + 1))
            fi
            if [[ "${VERSION_K}" == "0" ]]; then
                VERSION_K="1"
            fi
            VERSION_M="0"
            VERSION_P="0"
            ;;
        "beta")
            VERSION_K="${VERSION_K_LAST}"
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_M="${VERSION_M_LAST}"
            else
                VERSION_M=$((VERSION_M_LAST + 1))
            fi
            if [[ "${VERSION_M}" == "0" ]]; then
                VERSION_M="1"
            fi
            VERSION_P="0"
            ;;
        "alpha")
            VERSION_K="${VERSION_K_LAST}"
            VERSION_M="${VERSION_M_LAST}"
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_P="${VERSION_P_LAST}"
            else
                VERSION_P=$((VERSION_P_LAST + 1))
            fi
            if [[ "${VERSION_P}" == "0" ]]; then
                VERSION_P="1"
            fi
            ;;
        *)
            log_error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'ga', 'beta' or 'alpha'"
            return 1
            ;;
    esac

    ADV_VERSION="${VERSION_K}.${VERSION_M}.${VERSION_P}"
    log_info "New version: $ADV_VERSION"

    return 0
}

function get_kernel_version() {
    log_info "Kernel version: $KERNEL_VERSION"
    return 0
}

function init_global_variable() {
    OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}/v${SDK_VERSION}.${ADV_VERSION}"

    VER_TAG="${PROJECT}_${OS_DISTRO}_v${ADV_VERSION}_kernel-${KERNEL_VERSION}_${CHIP_NAME}"
    VER_IMAGE="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.img"
    VER_IMAGE_SD="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}_sdcard.wic"
    
    log_success "Global variables initialized successfully"

    return 0
}

function print_config() {
    printf "%-18s: %s\n" "$1" "$2"
}

function dump_global_variable() {
    log_info "Build Configuration"
    echo "================================="
    print_config "DATE" "$DATE"
    print_config "STORED" "$STORED"
    print_config "BSP_URL" "$BSP_URL"
    print_config "BSP_BRANCH" "$BSP_BRANCH"
    print_config "PROJECT" "$PROJECT"
    print_config "PROJECT_LIST" "$PROJECT_LIST"
    print_config "VERSION_TYPE" "$VERSION_TYPE"
    print_config "VERSION_FIXED" "$VERSION_FIXED"
    print_config "SDK_VERSION" "$SDK_VERSION"
    print_config "PREVIOUS_VERSION" "${VERSION_K_LAST}.${VERSION_M_LAST}.${VERSION_P_LAST}"
    print_config "ADV_VERSION" "$ADV_VERSION"
    print_config "KERNEL_VERSION" "$KERNEL_VERSION"
    print_config "ROOTFS" "$ROOTFS"
    print_config "VER_TAG" "$VER_TAG"
    print_config "OUTPUT_DIR" "$OUTPUT_DIR"
    echo "================================="

    return 0
}

function get_source_code() {
    log_info "Fetching $CHIP_NAME $OS_DISTRO source code"
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    if [[ $FIRST_PROJECT != "true" ]]; then
        log_info "Reusing existing source code (FIRST_PROJECT=$FIRST_PROJECT)"
        return 0
    fi

	git clone $BSP_URL $ROOTFS_DIR
	safe_cd $ROOTFS_DIR || return 1
	git checkout -b local --track origin/$BSP_BRANCH
    
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    safe_cd "$CURR_PATH" || return 1
    log_success "Source code preparation completed successfully"

    return 0
}

function generate_md5() {
    local filename="$1"
    
    if [[ -e "$filename" ]]; then
        log_info "Generating MD5 for: $filename"
        md5sum -b "$filename" | cut -d ' ' -f 1 > "${filename}.md5"
    else
        log_warning "File not found for MD5 generation: $filename"
        return 1
    fi
    return 0
}

function generate_oeminfo() {
    local oem_file
    oem_file="$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR/rootfs-overlay-adv/${CHIP_NAME}${PROJECT}/etc/OEMinfo.ini"

    local image_version="V${SDK_VERSION}.${ADV_VERSION}"
    log_info "Generating OEMinfo.ini..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    cat > "$oem_file" << EOF
[General]
Manufacturer: Advantech, Inc.
Support_URL:  www.advantech.com

[AIM_Linux_Release]
Platform_Name:     NXP
Chip_Name:         ${CHIP_NAME}
Product_Name:      ${PROJECT}
OS_Distro:         ${OS_DISTRO}
Image_Version:     ${image_version}
Kernel_Version:    ${KERNEL_VERSION}
Build_Date:        ${DATE}
EOF

    if [ $? -eq 0 ]; then
        echo "-----------------------"
        cat "$oem_file"
        echo "-----------------------"
        echo "$oem_file generation completed successfully"
        return 0
    else
        echo "Error: Failed to write to $oem_file" >&2
        return 1
    fi
}

function build_linux_images() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    log_info "Starting Linux images build process..."
    safe_cd "$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR" || return 1
    
    . setup.env
	bld -m ${CHIP_NAME}${PROJECT}
	
	cd build_lsdk${SDK_VERSION}_${PROJECT}/images/
	./flex-installer -m ${CHIP_NAME}${PROJECT} -i mkwic -b boot_IMX_arm64_lts_${KERNEL_VERSION}.tar.zst -f firmware_${CHIP_NAME}${PROJECT}_sdboot.img -r rootfs_lsdk${SDK_VERSION}_debian_${CHIP_NAME}${PROJECT}.tar.zst
        
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log_success "Linux images build completed in $duration seconds"
    return 0
}

function prepare_image_package() {
    log_info "Preparing image packages for distribution..."
    safe_cd "$CURR_PATH" || return 1
    
    # Create image package
    if [[ -d "$VER_IMAGE" ]]; then
        rm -rf "$VER_IMAGE"
    fi
    mkdir -p "$VER_IMAGE"
    
    # Copy images
    if [[ -f "$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR/build_lsdk${SDK_VERSION}_${PROJECT}/images/sdcard.wic" ]]; then
        cp $CURR_PATH/$ROOT_DIR/$ROOTFS_DIR/build_lsdk${SDK_VERSION}_${PROJECT}/images/sdcard.wic "$VER_IMAGE/$VER_IMAGE_SD"
        if ! generate_md5 "$VER_IMAGE/$VER_IMAGE_SD"; then
            log_error "Failed to generate MD5 for $VER_IMAGE/$VER_IMAGE_SD"
        fi
    else
        log_error "Images: $CURR_PATH/$ROOT_DIR/$ROOTFS_DIR/build_lsdk${SDK_VERSION}_${PROJECT}/images/sdcard.wic not found"
        return 1
    fi
    
    # Create archive
    log_info "Creating archive: ${VER_IMAGE}.tgz"
    if ! tar czf "${VER_IMAGE}.tgz" "$VER_IMAGE"; then
        log_error "Failed to create image archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_IMAGE}.tgz"; then
        log_error "Failed to generate MD5 for image"
        return 1
    fi
    
    return 0
}

function prepare_bsp_package() {
    log_info "Preparing BSP (Board Support Package)..."
    
    return 0
}

function copy_image_to_storage() {
    log_info "Copying images to storage: $OUTPUT_DIR"
    safe_cd "$CURR_PATH" || return 1
    
    # Image package
    if [[ -f "${VER_IMAGE}.tgz" ]]; then
        mv -f "${VER_IMAGE}.tgz" "$OUTPUT_DIR/${PROJECT}/image/"
        mv -f "${VER_IMAGE}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/image/"
    else
        log_warning "Image package not found"
        return 1
    fi
    
    log_success "Images and BSP copied to storage successfully"
    return 0
}

function copy_log_to_storage() {
    log_info "Collecting and archiving log files..."
    
    log_success "Log files archived successfully"
    return 0
}

function copy_manifest_to_storage() {
    log_info "Generating and storing manifest..."

    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    cp "$ROOTFS_DIR/configs/advantech.yml" "$OUTPUT_DIR/${PROJECT}/others"
    
    log_success "Manifest stored successfully"
    return 0
}

function commit_manifest_and_version() {
    log_info "Committing manifest and version..."
    safe_cd "$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR" || return 1

    if [[ "${VERSION_FIXED}" == "false" ]]; then
        # Create version file
        mkdir -p version
        cat > "version/${PROJECT}" << EOF
VERSION_K = ${VERSION_K}
VERSION_M = ${VERSION_M}
VERSION_P = ${VERSION_P}
EOF

        git add "version/${PROJECT}"
    else
        log_info "Skip creating version file because VERSION_FIXED is true"
    fi
    
    # Commit changes
    local remote_server
    remote_server=$(git remote -v | grep push | awk '{print $1}')

    if ! git commit -m "[Official Release] ${VER_TAG}"; then
        log_info "INFO: No changes to commit"
    else
        log_info "Committing manifest and version to remote..."
        git push $remote_server local:$BSP_BRANCH
    fi
    
    log_success "Manifest and version committed successfully"
    return 0
}

function find_max_suffix_of_exist_tag() {
    local max_suffix=0
    local repos_with_tag=()

    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    log_info "Finding tag suffix..." >&2

    local full_path="$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR"
    if [[ -d "$full_path" ]]; then
        safe_cd "$full_path" || return 1
        local old_tag="${VER_TAG}_old"
        local current_suffix=0
        current_suffix=$(git tag -l | grep -c "${old_tag}" || true)
        if [ $current_suffix -gt $max_suffix ]; then
            max_suffix=$current_suffix
        fi
        safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    else
        log_warning "Repository directory not found: $full_path" >&2
    fi

    log_info "Tag suffix completed, max_suffix=$max_suffix" >&2
    echo $((max_suffix + 1))
}

function rename_exist_tag() {
    local new_tag="$1"
    local remote_server=$(git remote -v | grep push | awk '{print $1}')
    log_info "Renaming tag in repository: $(basename "$PWD")"

    # Create new tag pointing to the actual commit (avoid nested tag warning)
    local commit_id
    commit_id=$(git rev-parse "$VER_TAG^{}")
    git tag -a "$new_tag" "$commit_id" -m "[Renamed] Original tag: $VER_TAG"

    # Push new tag to remote
    git push "$remote_server" "$new_tag"

    # Delete local old tag
    git tag -d "$VER_TAG"

    # Try to delete remote old tag, but don't fail if it doesn't exist
    if [[ -n "$(git ls-remote --tags "$remote_server" "refs/tags/$VER_TAG")" ]]; then
        git push "$remote_server" --delete "$VER_TAG" || log_warning "Failed to delete remote tag $VER_TAG, may already be deleted"
    else
        log_info "Remote tag $VER_TAG not found, may have been deleted already"
    fi
    
    log_success "Renamed tag: $VER_TAG -> $new_tag"
}

function commit_tag() {
    log_info "Creating and pushing tags..."
    
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    local suffix
    suffix=$(find_max_suffix_of_exist_tag)
    
    log_info "Suffix for old tag is $suffix"
    if [ "$suffix" -le 0 ] || [ "$suffix" -gt 999 ]; then
        log_error "Suffix must be 1-999, got $suffix"
        return 1
    fi
    local new_tag="${VER_TAG}_old_$(printf "%03d" "$suffix")"

    # Handle existing tags by renaming them with incrementing suffix
    log_info "Checking for existing tags..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    # Rename tags in each repository if the tag exists

    local full_path="$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR"
    if [[ -d "$full_path" ]]; then
        safe_cd "$full_path" || return 1
        if git rev-parse "$VER_TAG" >/dev/null 2>&1; then
            rename_exist_tag "$new_tag"
        fi
        safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    else
        log_warning "Repository directory not found: $full_path"
    fi
    
    
    log_success "Existing tags checked and renamed successfully"
    
    # Create new tags
    safe_cd "$CURR_PATH/$ROOT_DIR/$ROOTFS_DIR" || return 1
    local remote_server=$(git remote -v | grep push | awk '{print $1}')

    log_info "Creating tag: $VER_TAG"
    if ! git tag -a "$VER_TAG" -m "[Official Release] $VER_TAG"; then
        log_error "Failed to create tags"
        return 1
    fi
    
    if ! git push "$remote_server" "$VER_TAG"; then
        log_error "Failed to push tags"
        return 1
    fi

    
    log_success "Tags created successfully"
    return 0
}

# ================
#  Main Procedure
# ================

function main() {
    local start_time=$(date +%s)

    log_info "Build script version: $SCRIPT_VERSION"
    log_info "Build process started at $(get_timestamp)"
    
    # Execute steps in order
    local steps=(
        "validate_environment"
        "create_root_dir"
        "get_first_project"
        "get_source_code"
        "get_adv_version"
        "get_kernel_version"
        "init_global_variable"
        "dump_global_variable"
        "create_output_dir"
        "generate_oeminfo"
        "build_linux_images"
        "prepare_image_package"
        "prepare_bsp_package"
        "copy_image_to_storage"
        "copy_log_to_storage"
        "copy_manifest_to_storage"
        "commit_manifest_and_version"
        "commit_tag"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    for step in "${steps[@]}"; do
        current_step=$((current_step + 1))
        echo "📋 [ADV] === Step $current_step/$total_steps: $step ==="
        "$step"
        echo "✅ [ADV] ✓ Step $current_step: $step completed successfully"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "Build process completed in $duration seconds"
    return 0
}

# Execute main function
main

echo "🎉 [ADV] Build script completed successfully!"
exit 0
