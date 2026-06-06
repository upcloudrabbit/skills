#!/usr/bin/env bash
#
# package.sh — Package all .SKILL directories into zip files under resources/
#
# Usage: ./package.sh
#
# For each <name>.SKILL/ directory in the project root, creates
# resources/<name>.zip, ready for import by cc-switch or similar tools.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${ROOT_DIR}/resources"
SKILL_PATTERN="*.SKILL"

rm -rf "${RESOURCES_DIR}"
mkdir -p "${RESOURCES_DIR}"

count=0
for skill_dir in "${ROOT_DIR}"/${SKILL_PATTERN}; do
    [ -d "${skill_dir}" ] || continue

    dir_name="$(basename "${skill_dir}")"
    # Strip trailing .SKILL (case-insensitive)
    skill_name="${dir_name%.SKILL}"
    skill_name="${skill_name%.skill}"

    zip_file="${RESOURCES_DIR}/${skill_name}.zip"

    echo "Packaging: ${dir_name} -> ${zip_file}"
    (cd "${ROOT_DIR}" && zip -r "${zip_file}" "${dir_name}" -x ".*" > /dev/null)

    count=$((count + 1))
done

if [ "${count}" -eq 0 ]; then
    echo "No ${SKILL_PATTERN} directories found in ${ROOT_DIR}."
    rmdir "${RESOURCES_DIR}" 2>/dev/null || true
    exit 0
fi

echo ""
echo "Done. ${count} skill(s) packaged into: ${RESOURCES_DIR}"
ls -lh "${RESOURCES_DIR}"/*.zip 2>/dev/null
