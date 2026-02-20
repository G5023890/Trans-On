#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd -P)"
MODE="dry-run"
AUTO_YES="0"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/safe_clean.sh            # dry-run (default)
  ./scripts/safe_clean.sh --dry-run  # dry-run
  ./scripts/safe_clean.sh --apply    # delete after interactive confirmation
  ./scripts/safe_clean.sh --apply --yes  # delete without interactive confirmation
EOF
}

while (($# > 0)); do
  case "$1" in
    --dry-run)
      MODE="dry-run"
      ;;
    --apply)
      MODE="apply"
      ;;
    --yes)
      AUTO_YES="1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ ! -d "$ROOT" ]]; then
  echo "Current directory does not exist: $ROOT" >&2
  exit 1
fi

human_kib() {
  local kib="$1"
  if (( kib < 1024 )); then
    printf "%d KiB" "$kib"
  elif (( kib < 1024 * 1024 )); then
    awk -v n="$kib" 'BEGIN { printf "%.2f MiB", n/1024 }'
  else
    awk -v n="$kib" 'BEGIN { printf "%.2f GiB", n/1024/1024 }'
  fi
}

is_go_bin_artifact_dir() {
  local dir="$1"

  # Conservative heuristic: treat as build artifact only when it contains
  # executable files and no Go source files.
  local has_exec="0"
  local has_go_src="0"

  while IFS= read -r -d '' f; do
    if [[ -x "$f" ]]; then
      has_exec="1"
    fi
    if [[ "$f" == *.go ]]; then
      has_go_src="1"
    fi
  done < <(find "$dir" -mindepth 1 -maxdepth 3 -type f -print0 2>/dev/null || true)

  [[ "$has_exec" == "1" && "$has_go_src" == "0" ]]
}

RAW_LIST="$(mktemp)"
trap 'rm -f "$RAW_LIST"' EXIT

add_find_dir_name() {
  local name="$1"
  find "$ROOT" -path "$ROOT/.git" -prune -o -type d -name "$name" -print >> "$RAW_LIST"
}

add_find_file_name() {
  local name="$1"
  find "$ROOT" -path "$ROOT/.git" -prune -o -type f -name "$name" -print >> "$RAW_LIST"
}

# Common
add_find_dir_name "node_modules"
add_find_dir_name "dist"
add_find_dir_name "build"
add_find_dir_name ".cache"
add_find_dir_name "tmp"
add_find_dir_name ".tmp"
add_find_file_name "*.log"
add_find_file_name ".DS_Store"

# Swift / Xcode
add_find_dir_name ".build"
add_find_dir_name "DerivedData"   # scoped to current project tree only
add_find_file_name "*.xcuserstate"
add_find_dir_name "xcuserdata"

# Python
add_find_dir_name "__pycache__"
add_find_dir_name ".pytest_cache"
add_find_dir_name ".mypy_cache"
add_find_file_name "*.pyc"

# Rust
add_find_dir_name "target"

# Go (bin only if build artifact)
add_find_dir_name "pkg"
while IFS= read -r dir; do
  if is_go_bin_artifact_dir "$dir"; then
    printf '%s\n' "$dir" >> "$RAW_LIST"
  fi
done < <(find "$ROOT" -path "$ROOT/.git" -prune -o -type d -name "bin" -print)

# C/C++
add_find_dir_name "CMakeFiles"
add_find_file_name "CMakeCache.txt"

# Codex
add_find_dir_name ".codex"
add_find_dir_name ".agent"

UNIQUE_PATHS=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  UNIQUE_PATHS+=("$line")
done < <(sort -u "$RAW_LIST")

# Keep top-level candidates only (avoid nested duplicates and double counting)
SORTED_BY_LEN=()
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  SORTED_BY_LEN+=("$line")
done < <(
  if ((${#UNIQUE_PATHS[@]} > 0)); then
    printf '%s\n' "${UNIQUE_PATHS[@]}" | awk '{ print length($0) "\t" $0 }' | sort -n -k1,1 -k2,2 | cut -f2-
  fi
)

FINAL_PATHS=()
if ((${#SORTED_BY_LEN[@]} > 0)); then
  for p in "${SORTED_BY_LEN[@]}"; do
    [[ -n "$p" ]] || continue
    [[ -e "$p" ]] || continue

    # Absolute safety: never touch anything outside ROOT and never touch .git
    if [[ "$p" != "$ROOT"/* ]]; then
      continue
    fi
    if [[ "$p" == "$ROOT/.git" || "$p" == "$ROOT/.git/"* ]]; then
      continue
    fi

    skip="0"
    if ((${#FINAL_PATHS[@]} > 0)); then
      for kept in "${FINAL_PATHS[@]}"; do
        if [[ "$p" == "$kept" || "$p" == "$kept/"* ]]; then
          skip="1"
          break
        fi
      done
    fi
    if [[ "$skip" == "0" ]]; then
      FINAL_PATHS+=("$p")
    fi
  done
fi

PROJECT_SIZE_BEFORE_KIB="$(du -sk "$ROOT" | awk '{print $1}')"

TOTAL_REMOVE_KIB=0

echo "Project root: $ROOT"
echo "Project size (before): $(human_kib "$PROJECT_SIZE_BEFORE_KIB")"
echo

if ((${#FINAL_PATHS[@]} == 0)); then
  echo "No matching cache/build artifacts found."
  echo "Total to remove: 0 KiB"
  exit 0
fi

echo "Candidates for cleanup:"
for p in "${FINAL_PATHS[@]}"; do
  size_kib="$(du -sk "$p" | awk '{print $1}')"
  TOTAL_REMOVE_KIB=$((TOTAL_REMOVE_KIB + size_kib))
  rel="${p#"$ROOT"/}"
  if [[ "$p" == "$ROOT" ]]; then
    rel="."
  fi
  printf "  - %s (%s)\n" "$rel" "$(human_kib "$size_kib")"
done

echo
echo "Total to remove: $(human_kib "$TOTAL_REMOVE_KIB")"

if [[ "$MODE" != "apply" ]]; then
  echo
  echo "Dry-run only. No files were deleted."
  echo "Run with --apply to perform deletion."
  exit 0
fi

echo
if [[ "$AUTO_YES" != "1" ]]; then
  read -r -p "Proceed with deletion of the listed items? [y/N]: " answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Cancelled. Nothing deleted."
      exit 0
      ;;
  esac
fi

for p in "${FINAL_PATHS[@]}"; do
  [[ "$p" == "$ROOT"/* ]] || continue
  [[ "$p" == "$ROOT/.git" || "$p" == "$ROOT/.git/"* ]] && continue

  if [[ -d "$p" ]]; then
    rm -rf -- "$p"
  else
    rm -f -- "$p"
  fi
done

PROJECT_SIZE_AFTER_KIB="$(du -sk "$ROOT" | awk '{print $1}')"
RECLAIMED_KIB=$((PROJECT_SIZE_BEFORE_KIB - PROJECT_SIZE_AFTER_KIB))
if (( RECLAIMED_KIB < 0 )); then
  RECLAIMED_KIB=0
fi

echo
echo "Project size (after): $(human_kib "$PROJECT_SIZE_AFTER_KIB")"
echo "Space reclaimed: $(human_kib "$RECLAIMED_KIB")"
