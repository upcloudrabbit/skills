#!/usr/bin/env bash
#
# package.sh — Package all skill directories into zip files under resources/
#
# Usage: ./package.sh
#
# For each directory in the project root that contains a SKILL.md file,
# creates resources/<name>.zip, ready for import by cc-switch or similar tools.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="${ROOT_DIR}/resources"

rm -rf "${RESOURCES_DIR}"
mkdir -p "${RESOURCES_DIR}"

count=0
for skill_dir in "${ROOT_DIR}"/*/; do
    [ -f "${skill_dir}SKILL.md" ] || continue

    dir_name="$(basename "${skill_dir}")"
    zip_file="${RESOURCES_DIR}/${dir_name}.zip"

    echo "Packaging: ${dir_name} -> ${zip_file}"
    (cd "${ROOT_DIR}" && zip -r "${zip_file}" "${dir_name}" -x ".*" > /dev/null)

    count=$((count + 1))
done

if [ "${count}" -eq 0 ]; then
    echo "No skill directories (with SKILL.md) found in ${ROOT_DIR}."
    rmdir "${RESOURCES_DIR}" 2>/dev/null || true
    exit 0
fi

echo ""
echo "Done. ${count} skill(s) packaged into: ${RESOURCES_DIR}"
ls -lh "${RESOURCES_DIR}"/*.zip 2>/dev/null
