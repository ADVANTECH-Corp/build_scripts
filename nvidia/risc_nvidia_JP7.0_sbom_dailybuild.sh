#!/usr/bin/env bash

echo "Start CVE generate process"
source azure_env.sh
echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] BSP_XML = ${BSP_XML}"
echo "[ADV] PLATFORM_PREFIX = ${PLATFORM_PREFIX}"
echo "[ADV] TARGET_BOARD=$TARGET_BOARD"
echo "[ADV] PROJECT=$PROJECT"
echo "[ADV] OS_VERSION=$OS_VERSION"
echo "[ADV] KERNEL_VERSION=$KERNEL_VERSION"
echo "[ADV] SOC_MEM=$SOC_MEM"
echo "[ADV] STORAGE=$STORAGE"
echo "[ADV] RELEASE_VERSION=$RELEASE_VERSION"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
LINUX_TEGRA="Linux_for_Tegra"
#IMAGE_VER="${PROJECT}_${OS_VERSION}${RELEASE_VERSION}_${KERNEL_VERSION}_${SOC_MEM}_${STORAGE}_${DATE}"
IMAGE_VER="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"


set -euo pipefail

# =========================
# Config (edit if needed)
# =========================
BASE_IMAGE="nvcr.io/nvidia/l4t-jetpack:r36.4.0"
QEMU_IMAGE="multiarch/qemu-user-static:latest"
TAG_NAME="nv_cve_docker_image"
PLATFORM="linux/arm64"
DOCKERFILE_PATH="./Dockerfile"
ROOTFS_DIR="./Linux_for_Tegra/rootfs"

# If you want a specific buildx builder name, set it here:
BUILDER_NAME="nv-buildx"

# Clean up the buildx builder and its BuildKit cache volume after this job.
# Set to "false" if you want to keep build cache for faster local rebuilds.
CLEANUP_BUILDX_STATE="true"

# =========================
# Helpers
# =========================
log() { echo -e "\n[INFO] $*\n"; }
err() { echo -e "\n[ERROR] $*\n" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }
}

# =========================
# Preflight
# =========================
need_cmd sudo
need_cmd apt
need_cmd docker

pushd ${OUTPUT_DIR}/ 2>&1 > /dev/null

if [ ! -f "${IMAGE_VER}.tgz" ]; then
    log "[ERROR] Image not found: ${OUTPUT_DIR}/${IMAGE_VER}.tgz"
    exit 1
fi

sudo tar -zxvf ${IMAGE_VER}.tgz


if [[ ! -d "${ROOTFS_DIR}" ]]; then
  err "Rootfs directory not found: ${ROOTFS_DIR}"
  err "Expected: ${ROOTFS_DIR} (used by Dockerfile: COPY Linux_for_Tegra/rootfs/ /)"
  exit 1
fi

# =========================
# 1) Pull base image
# =========================
log "Pull base image: ${BASE_IMAGE}"
sudo docker pull "${BASE_IMAGE}"

# =========================
# 2) Install qemu-user-static + binfmt-support
# =========================
log "Install qemu-user-static and binfmt-support"
sudo apt update
sudo apt install -y qemu-user-static binfmt-support

# =========================
# 3) Register binfmt for multiarch (QEMU)
# =========================
log "Register binfmt via ${QEMU_IMAGE}"
sudo docker run --rm --privileged "${QEMU_IMAGE}" --reset -p yes

# =========================
# 4) Create Dockerfile in current folder
# =========================
log "Generate Dockerfile: ${DOCKERFILE_PATH}"
cat > "${DOCKERFILE_PATH}" <<'EOF'
# Dockerfile

# 1) First start from nvcr.io/nvidia/l4t-jetpack:r36.4.0
FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

# 2) Copy QEMU static files from qemu-static docker image
COPY --from=multiarch/qemu-user-static:latest /usr/bin/qemu-aarch64-static /usr/bin

# 3) Copy target rootfs, to override original rootfs
COPY Linux_for_Tegra/rootfs/ /

# 4) Set default command system
CMD ["/bin/bash"]
EOF

# =========================
# 5) Ensure buildx builder exists and is selected
# =========================
log "Setup docker buildx builder: ${BUILDER_NAME}"
sudo docker buildx rm "${BUILDER_NAME}" 2>/dev/null || true
sudo docker buildx create --name "${BUILDER_NAME}" --use
sudo docker buildx inspect --bootstrap >/dev/null

# =========================
# 6) Build image for linux/arm64 and --load into local docker
# =========================
log "Build image: ${TAG_NAME} (platform=${PLATFORM})"


sudo docker image rm ${TAG_NAME} >/dev/null 2>&1 || true

sudo docker buildx build \
  --no-cache \
  --platform "${PLATFORM}" \
  -t "${TAG_NAME}" \
  --load \
  .

log "Done."
log "Result image: ${TAG_NAME}"

IMAGE="${TAG_NAME}"
PLATFORM="linux/arm64"

WORKDIR="$(pwd)"
CVE_BIN_TOOL_VENV="${WORKDIR}/.venv-cve-bin-tool"
SUMMARY_PATCH_SCRIPT="${WORKDIR}/patch_cve_html_summary.py"

ensure_cve_bin_tool() {
  log "Check cve-bin-tool on host"

  if ! command -v cve-bin-tool >/dev/null 2>&1; then
    log "Install cve-bin-tool into host Python venv: ${CVE_BIN_TOOL_VENV}"
    sudo apt update
    sudo apt install -y \
      python3 python3-venv python3-pip \
      file binutils tar unzip rpm2cpio cpio cabextract

    python3 -m venv "${CVE_BIN_TOOL_VENV}"
    "${CVE_BIN_TOOL_VENV}/bin/python" -m pip install --upgrade pip
    "${CVE_BIN_TOOL_VENV}/bin/pip" install --upgrade cve-bin-tool

    export PATH="${CVE_BIN_TOOL_VENV}/bin:${PATH}"
  fi

  cve-bin-tool --version
}

patch_cve_html_summary() {
  log "Generate HTML summary patch script: ${SUMMARY_PATCH_SCRIPT}"
  cat > "${SUMMARY_PATCH_SCRIPT}" <<'PY'
#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

if len(sys.argv) != 5:
    print("Usage: patch_cve_html_summary.py SBOM.json cve_report.json input.html output.html")
    sys.exit(1)

sbom_file, cve_json_file, html_in, html_out = sys.argv[1:5]

sbom = json.loads(Path(sbom_file).read_text(encoding="utf-8"))
cve_rows = json.loads(Path(cve_json_file).read_text(encoding="utf-8"))
html = Path(html_in).read_text(encoding="utf-8")

package_count = len(sbom.get("packages", []))

vulnerable_products = {
    (
        row.get("vendor", "UNKNOWN"),
        row.get("product", ""),
        row.get("version", ""),
    )
    for row in cve_rows
}

vuln_count = len(vulnerable_products)
no_known = max(package_count - vuln_count, 0)

def replace_first_number_after(label, value, text):
    label_pos = text.lower().find(label.lower())
    if label_pos == -1:
        return text

    window_start = label_pos
    window_end = min(len(text), label_pos + 800)
    window = text[window_start:window_end]

    patched, count = re.subn(
        r'(<span[^>]*class="[^"]*badge[^"]*"[^>]*>)\d+(</span>)',
        rf'\g<1>{value}\2',
        window,
        count=1,
        flags=re.I | re.S,
    )

    if count == 0:
        patched, count = re.subn(r'(\b)\d+(\b)', rf'\g<1>{value}\2', window, count=1)

    if count == 0:
        return text

    return text[:window_start] + patched + text[window_end:]

html = replace_first_number_after("Scanned Files:", package_count, html)
html = replace_first_number_after("Total Scanned Files", package_count, html)
html = replace_first_number_after("Vulnerable Files:", vuln_count, html)
html = replace_first_number_after("Vulnerable Files", vuln_count, html)
html = replace_first_number_after("No Known Vulnerability", no_known, html)

Path(html_out).write_text(html, encoding="utf-8")

audit = {
    "source_flow": "syft SBOM -> cve-bin-tool HTML/JSON -> patched HTML summary",
    "sbom_file": sbom_file,
    "cve_json_file": cve_json_file,
    "sbom_package_count": package_count,
    "cve_bin_tool_vulnerable_product_count": vuln_count,
    "no_known_vulnerability_count": no_known,
    "vulnerable_products": sorted(list(vulnerable_products)),
}

Path(html_out + ".audit.json").write_text(json.dumps(audit, indent=2), encoding="utf-8")
print(json.dumps(audit, indent=2))
PY
}

echo "[INFO] Workdir : ${WORKDIR}"
echo "[INFO] Image   : ${IMAGE}"
echo "[INFO] Platform: ${PLATFORM}"
echo

read -r -d '' CONTAINER_CMD <<EOF || true
set -uo pipefail

echo "[INFO] Container OS:"
cat /etc/os-release || true
echo

echo "[INFO] apt update (allow failure)"
sudo apt update || echo "[WARN] apt update failed, continue anyway"

echo "[INFO] install base tools (best effort)"
sudo apt install -y curl wget gnupg python3 ca-certificates || echo "[WARN] apt install base tools failed (maybe already installed)"

echo
echo "[INFO] Install syft"
if ! command -v syft >/dev/null 2>&1; then
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi
syft version || true
echo

echo "[INFO] Generate SBOM.json"
sudo syft / --output spdx-json > /work/SBOM.json
echo

echo "[INFO] Output files:"
ls -al /work | egrep 'SBOM\.json' || true
echo

echo "[INFO] Done generating SBOM.json in container."
EOF

echo "[INFO] Starting container..."
sudo docker run --rm -i --platform="${PLATFORM}" \
  -v "${WORKDIR}":/work \
  -w /work \
  "${IMAGE}" \
  bash -lc "${CONTAINER_CMD}"

ensure_cve_bin_tool
patch_cve_html_summary

log "Generate CVE report HTML/JSON by cve-bin-tool on host"
cve-bin-tool --sbom spdx \
  --sbom-file "${WORKDIR}/SBOM.json" \
  --format html,json \
  --output-file "${WORKDIR}/${IMAGE_VER}_sbom" \
  --update daily \
  -n json-mirror \
  --disable-data-source OSV

log "Patch cve-bin-tool HTML summary with SBOM package count"
python3 "${SUMMARY_PATCH_SCRIPT}" \
  "${WORKDIR}/SBOM.json" \
  "${WORKDIR}/${IMAGE_VER}_sbom.json" \
  "${WORKDIR}/${IMAGE_VER}_sbom.html" \
  "${WORKDIR}/${IMAGE_VER}_sbom.html"

if [ ! -f "${WORKDIR}/${IMAGE_VER}_sbom.html" ]; then
    if [  -f "Linux_for_Tegra" ]; then
      sudo rm -rf Linux_for_Tegra
      sudo rm -f SBOM.json Dockerfile "${SUMMARY_PATCH_SCRIPT}"
    fi
    log "[ERROR] File not found: ${WORKDIR}/${IMAGE_VER}_sbom.html"
    exit 1
fi

md5sum ${IMAGE_VER}_sbom.html | awk '{print $1}' > ${IMAGE_VER}_sbom.html.md5
echo "[INFO] Generated ${IMAGE_VER}_sbom.html.md5 "



echo
echo "[INFO] Back on host. Verify outputs:"
ls -al "${WORKDIR}" | egrep "SBOM\.json|${IMAGE_VER}_sbom\.html|${IMAGE_VER}_sbom\.json|${IMAGE_VER}_sbom\.html\.md5|${IMAGE_VER}_sbom\.html\.audit\.json" || true
sudo rm -rf SBOM.json Dockerfile "${SUMMARY_PATCH_SCRIPT}" Linux_for_Tegra/
if [  -f "Linux_for_Tegra" ]; then
    sudo rm -rf Linux_for_Tegra
fi
sudo docker image rm ${IMAGE}

if [ "${CLEANUP_BUILDX_STATE}" = "true" ]; then
    log "Clean up docker buildx builder and BuildKit state: ${BUILDER_NAME}"
    if sudo docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
        if sudo docker buildx rm "${BUILDER_NAME}"; then
            log "Removed docker buildx builder: ${BUILDER_NAME}"
        else
            err "Failed to remove docker buildx builder: ${BUILDER_NAME}"
        fi
    else
        log "Docker buildx builder already absent: ${BUILDER_NAME}"
    fi

    BUILDX_STATE_VOLUME="buildx_buildkit_${BUILDER_NAME}0_state"
    if sudo docker volume inspect "${BUILDX_STATE_VOLUME}" >/dev/null 2>&1; then
        if sudo docker volume rm "${BUILDX_STATE_VOLUME}"; then
            log "Removed docker buildx state volume: ${BUILDX_STATE_VOLUME}"
        else
            err "Failed to remove docker buildx state volume: ${BUILDX_STATE_VOLUME}"
        fi
    else
        log "Docker buildx state volume already absent: ${BUILDX_STATE_VOLUME}"
    fi
fi

log "Clean up cve-bin-tool Python venv: ${CVE_BIN_TOOL_VENV}"
if [ -d "${CVE_BIN_TOOL_VENV}" ]; then
    if rm -rf "${CVE_BIN_TOOL_VENV}"; then
        log "Removed cve-bin-tool Python venv: ${CVE_BIN_TOOL_VENV}"
    else
        err "Failed to remove cve-bin-tool Python venv: ${CVE_BIN_TOOL_VENV}"
    fi
else
    log "cve-bin-tool Python venv already absent: ${CVE_BIN_TOOL_VENV}"
fi

echo
echo "[INFO] Finished. ${IMAGE_VER}_sbom.html is in: ${WORKDIR}"
