#!/usr/bin/env bash
# Run this script with bash, not with julia.
# Example:
#   bash scripts/run_smear_varrio_station1_winter_matrix.sh 2020 2024 varrio_station1_ri_curvature_tier1
set -euo pipefail

START_YEAR=${1:-2020}
END_YEAR=${2:-2024}
RUN_LABEL=${3:-varrio_station1_ri_curvature_tier1}
CONTINUE_ON_ERROR=${4:-false}

if [[ ${START_YEAR} -gt ${END_YEAR} ]]; then
  echo "start year must be <= end year" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT_DIR}"

MONTHS=(01 02 03 11 12)
BASE_DIR="runs/${RUN_LABEL}"
FAIL_LOG="${BASE_DIR}/failed_windows.txt"

mkdir -p "${BASE_DIR}/dct"
: > "${FAIL_LOG}"

is_true() {
  case "${1,,}" in
    1|true|yes|y) return 0 ;;
    *) return 1 ;;
  esac
}

echo "Starting Varrio station-1 winter matrix: ${START_YEAR}-${END_YEAR}"
echo "Run root: ${BASE_DIR}"
echo "Continue-on-error: ${CONTINUE_ON_ERROR}"

for year in $(seq "${START_YEAR}" "${END_YEAR}"); do
  for month in "${MONTHS[@]}"; do
    if [[ "${month}" == "12" ]]; then
      next_year=$((year + 1))
      next_month="01"
    else
      next_year=${year}
      next_month=$(printf "%02d" $((10#${month} + 1)))
    fi

    from_iso="${year}-${month}-01T00:00:00"
    to_iso="${next_year}-${next_month}-01T00:00:00"
    window_id="${year}_${month}"
    out_dir="${BASE_DIR}/dct/${window_id}"

    echo "---"
    echo "Window ${window_id}: ${from_iso} -> ${to_iso}"

    mkdir -p "${out_dir}"
    if ! DCT_SMEAR_START_DT="${from_iso}" \
      DCT_SMEAR_END_DT="${to_iso}" \
      DCT_SMEAR_OUT_DIR="${out_dir}" \
      julia --project=. -e 'include("src/julia/DCT_SMEAR.jl")'; then
      echo "FAILED ${window_id}: dct step" | tee -a "${FAIL_LOG}" >&2
      if is_true "${CONTINUE_ON_ERROR}"; then
        continue
      fi
      exit 1
    fi
  done
done

if [[ -s "${FAIL_LOG}" ]]; then
  echo "Varrio station-1 winter matrix completed with failures. See ${FAIL_LOG}" >&2
  if ! is_true "${CONTINUE_ON_ERROR}"; then
    exit 1
  fi
else
  rm -f "${FAIL_LOG}"
fi

echo "Varrio station-1 winter matrix complete: ${BASE_DIR}"
