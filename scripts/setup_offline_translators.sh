#!/usr/bin/env bash
set -euo pipefail

PYTHON_BIN="${PYTHON_BIN:-python3}"
OFFLINE_ROOT="${OFFLINE_TRANSLATORS_HOME:-$HOME/Library/Application Support/OfflineTranslators}"
VENV_DIR="${OFFLINE_TRANSLATORS_VENV:-$OFFLINE_ROOT/.venv}"
NLLB_DIR="${NLLB_MODEL_DIR:-$OFFLINE_ROOT/nllb}"
ARGOS_DIR="${OFFLINE_ARGOS_DIR:-$OFFLINE_ROOT/argos}"
SKIP_MODEL_DOWNLOAD="${SKIP_MODEL_DOWNLOAD:-0}"

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python not found: ${PYTHON_BIN}" >&2
  exit 1
fi

"${PYTHON_BIN}" - <<'PY'
import sys
if sys.version_info < (3, 11):
    print(f"Python 3.11+ is required. Current version: {sys.version}", file=sys.stderr)
    raise SystemExit(1)
PY

mkdir -p "${OFFLINE_ROOT}" "${NLLB_DIR}" "${ARGOS_DIR}"

if [ ! -x "${VENV_DIR}/bin/python" ]; then
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi
VENV_PYTHON="${VENV_DIR}/bin/python"

export HF_HUB_DISABLE_TELEMETRY=1
export DO_NOT_TRACK=1

"${VENV_PYTHON}" -m pip install --upgrade pip
"${VENV_PYTHON}" -m pip install ctranslate2 sentencepiece transformers torch

if [ "${SKIP_MODEL_DOWNLOAD}" = "1" ]; then
  echo "Dependencies installed in virtual env: ${VENV_DIR}"
  echo "Model download skipped (SKIP_MODEL_DOWNLOAD=1)."
  exit 0
fi

if [ -f "${NLLB_DIR}/model.bin" ]; then
  echo "NLLB CTranslate2 model already present: ${NLLB_DIR}"
  exit 0
fi

TMP_NLLB_DIR="${NLLB_DIR}.tmp.$$"
PREV_NLLB_DIR="${NLLB_DIR}.prev.$$"
rm -rf "${TMP_NLLB_DIR}" "${PREV_NLLB_DIR}"
mkdir -p "${TMP_NLLB_DIR}"

if [ -x "${VENV_DIR}/bin/ct2-transformers-converter" ]; then
  "${VENV_DIR}/bin/ct2-transformers-converter" \
    --model facebook/nllb-200-distilled-600M \
    --output_dir "${TMP_NLLB_DIR}" \
    --force \
    --quantization int8 \
    --copy_files sentencepiece.bpe.model tokenizer.json tokenizer_config.json special_tokens_map.json generation_config.json config.json
elif command -v ct2-transformers-converter >/dev/null 2>&1; then
  ct2-transformers-converter \
    --model facebook/nllb-200-distilled-600M \
    --output_dir "${TMP_NLLB_DIR}" \
    --force \
    --quantization int8 \
    --copy_files sentencepiece.bpe.model tokenizer.json tokenizer_config.json special_tokens_map.json generation_config.json config.json
else
  "${VENV_PYTHON}" -m ctranslate2.converters.transformers \
    --model facebook/nllb-200-distilled-600M \
    --output_dir "${TMP_NLLB_DIR}" \
    --force \
    --quantization int8 \
    --copy_files sentencepiece.bpe.model tokenizer.json tokenizer_config.json special_tokens_map.json generation_config.json config.json
fi

if [ ! -f "${TMP_NLLB_DIR}/model.bin" ]; then
  echo "Conversion failed: model.bin not found in temporary output ${TMP_NLLB_DIR}" >&2
  exit 1
fi

if [ -d "${NLLB_DIR}" ]; then
  mv "${NLLB_DIR}" "${PREV_NLLB_DIR}"
fi
mv "${TMP_NLLB_DIR}" "${NLLB_DIR}"
rm -rf "${PREV_NLLB_DIR}"

echo "Offline translator folders:"
echo "  ${ARGOS_DIR}"
echo "  ${NLLB_DIR}"
echo "Python virtual env: ${VENV_DIR}"
echo "Setup done."
