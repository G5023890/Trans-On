#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from typing import Dict, Optional, Protocol

SUPPORTED_LANGS = frozenset({"he", "en", "ru"})
SUPPORTED_MODES = frozenset({"auto", "fast", "quality"})

NLLB_LANG_CODES: Dict[str, str] = {
    "he": "heb_Hebr",
    "en": "eng_Latn",
    "ru": "rus_Cyrl",
}

HEBREW_RE = re.compile(r"[\u0590-\u05FF]")
CYRILLIC_RE = re.compile(r"[А-Яа-яЁё]")
LATIN_RE = re.compile(r"[A-Za-z]")


class EngineUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class TranslationResult:
    text: str
    engine: str
    source_lang: str
    target_lang: str
    elapsed_ms: float
    fallback_used: bool


class TranslationEngine(Protocol):
    name: str

    def is_available(self) -> bool:
        ...

    def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        ...


def normalize_lang(value: Optional[str], allow_auto: bool = False) -> str:
    normalized = (value or "").strip().lower()
    if normalized in {"", "auto"}:
        if allow_auto:
            return "auto"
        raise ValueError("Language must be one of: he, en, ru")

    aliases = {"iw": "he", "heb": "he", "eng": "en", "rus": "ru"}
    normalized = aliases.get(normalized, normalized)
    if normalized not in SUPPORTED_LANGS:
        raise ValueError(f"Unsupported language: {normalized}. Supported: {sorted(SUPPORTED_LANGS)}")
    return normalized


def normalize_mode(value: str) -> str:
    mode = (value or "auto").strip().lower()
    if mode not in SUPPORTED_MODES:
        raise ValueError(f"Unsupported mode: {mode}. Supported: {sorted(SUPPORTED_MODES)}")
    return mode


def detect_language(text: str) -> str:
    he_count = len(HEBREW_RE.findall(text))
    ru_count = len(CYRILLIC_RE.findall(text))
    en_count = len(LATIN_RE.findall(text))

    if he_count > 0 and he_count >= ru_count and he_count >= en_count:
        return "he"
    if ru_count > 0 and ru_count >= he_count and ru_count >= en_count:
        return "ru"
    if en_count > 0:
        return "en"
    return "en"


class ArgosEngine:
    name = "argos"

    def __init__(self, offline_root: str) -> None:
        self.offline_root = offline_root
        self.argos_root = os.path.expanduser(os.environ.get("OFFLINE_ARGOS_DIR", os.path.join(offline_root, "argos")))
        self.default_argos_root = os.path.expanduser("~/Library/Application Support/ArgosTranslate")
        self.cli_path = self._resolve_cli_path()
        self.environment = self._build_env()

    def _resolve_cli_path(self) -> Optional[str]:
        candidates = [
            os.environ.get("ARGOS_CLI_PATH"),
            os.path.join(self.argos_root, "bin", "argos-translate"),
            os.path.join(self.default_argos_root, "bin", "argos-translate"),
            shutil.which("argos-translate"),
        ]
        for candidate in candidates:
            if candidate and os.path.isfile(candidate) and os.access(candidate, os.X_OK):
                return candidate
        return None

    def _build_env(self) -> Dict[str, str]:
        env = dict(os.environ)

        default_packages_dir = os.path.join(self.argos_root, "packages")
        fallback_packages_dir = os.path.join(self.default_argos_root, "packages")
        env["ARGOS_PACKAGES_DIR"] = env.get("ARGOS_PACKAGES_DIR") or (
            default_packages_dir if os.path.isdir(default_packages_dir) else fallback_packages_dir
        )

        python_lib_paths = [
            os.path.join(self.argos_root, "python_lib"),
            os.path.join(self.default_argos_root, "python_lib"),
        ]
        existing = env.get("PYTHONPATH", "")
        merged = [p for p in python_lib_paths if os.path.isdir(p)]
        if existing:
            merged.append(existing)
        if merged:
            env["PYTHONPATH"] = ":".join(merged)
        return env

    def is_available(self) -> bool:
        return bool(self.cli_path)

    def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        if not self.cli_path:
            raise EngineUnavailable(
                "Argos CLI not found. Set ARGOS_CLI_PATH or install to "
                "~/Library/Application Support/OfflineTranslators/argos/bin/argos-translate."
            )

        args = [self.cli_path, "--text", text, "--to", target_lang]
        if source_lang != "auto":
            args.extend(["--from", source_lang])

        process = subprocess.run(
            args,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=self.environment,
            check=False,
        )
        if process.returncode != 0:
            error = process.stderr.strip() or f"exit code {process.returncode}"
            raise RuntimeError(f"Argos failed: {error}")

        output = process.stdout.strip()
        if not output:
            raise RuntimeError("Argos returned empty output")
        return output


class NLLBEngine:
    name = "nllb"

    def __init__(self, model_dir: str, compute_type: str = "int8") -> None:
        self.model_dir = os.path.expanduser(model_dir)
        self.compute_type = os.environ.get("NLLB_COMPUTE_TYPE", compute_type)
        self.device = os.environ.get("NLLB_DEVICE", "cpu")

        cpu_count = max(1, os.cpu_count() or 1)
        default_inter = max(1, cpu_count // 2)
        default_intra = max(1, cpu_count // default_inter)
        self.inter_threads = int(os.environ.get("NLLB_INTER_THREADS", default_inter))
        self.intra_threads = int(os.environ.get("NLLB_INTRA_THREADS", default_intra))
        self.beam_size = int(os.environ.get("NLLB_BEAM_SIZE", "4"))

        self._translator = None
        self._sp_model = None
        self._tokenizer = None
        self._load_lock = threading.Lock()

    def _sentencepiece_path(self) -> Optional[str]:
        candidates = [
            os.path.join(self.model_dir, "sentencepiece.bpe.model"),
            os.path.join(self.model_dir, "spm.model"),
            os.path.join(self.model_dir, "tokenizer.model"),
        ]
        for candidate in candidates:
            if os.path.isfile(candidate):
                return candidate
        return None

    def is_available(self) -> bool:
        return os.path.isfile(os.path.join(self.model_dir, "model.bin")) and self._sentencepiece_path() is not None

    def _load_once(self) -> None:
        if self._translator is not None and self._sp_model is not None and self._tokenizer is not None:
            return

        with self._load_lock:
            if self._translator is not None and self._sp_model is not None and self._tokenizer is not None:
                return
            if not self.is_available():
                raise EngineUnavailable(
                    "NLLB CT2 model is missing. Expected files in "
                    f"{self.model_dir} (model.bin + sentencepiece model)."
                )

            import ctranslate2  # type: ignore
            import sentencepiece as spm  # type: ignore
            from transformers import AutoTokenizer  # type: ignore
            from transformers.utils import logging as hf_logging  # type: ignore

            sp_path = self._sentencepiece_path()
            if sp_path is None:
                raise EngineUnavailable("SentencePiece model not found for NLLB.")

            hf_logging.set_verbosity_error()
            self._sp_model = spm.SentencePieceProcessor(model_file=sp_path)
            self._tokenizer = AutoTokenizer.from_pretrained(self.model_dir)
            self._translator = ctranslate2.Translator(
                self.model_dir,
                device=self.device,
                compute_type=self.compute_type,
                inter_threads=self.inter_threads,
                intra_threads=self.intra_threads,
            )

    def _lang_token(self, lang: str) -> str:
        return NLLB_LANG_CODES[lang]

    def translate(self, text: str, source_lang: str, target_lang: str) -> str:
        if source_lang not in SUPPORTED_LANGS or target_lang not in SUPPORTED_LANGS:
            raise ValueError("NLLB supports only he/en/ru in this setup")

        self._load_once()
        assert self._translator is not None
        assert self._sp_model is not None
        assert self._tokenizer is not None

        src_lang_code = self._lang_token(source_lang)
        tgt_lang_code = self._lang_token(target_lang)
        token_ids = self._tokenizer(text, src_lang=src_lang_code)["input_ids"]
        source_tokens = self._tokenizer.convert_ids_to_tokens(token_ids)

        results = self._translator.translate_batch(
            [source_tokens],
            target_prefix=[[tgt_lang_code]],
            beam_size=self.beam_size,
            return_scores=False,
        )
        if not results or not results[0].hypotheses:
            raise RuntimeError("NLLB returned no hypothesis")

        output_tokens = results[0].hypotheses[0]
        output_ids = self._tokenizer.convert_tokens_to_ids(output_tokens)
        translated = self._tokenizer.decode(output_ids, skip_special_tokens=True).strip()
        if not translated:
            raise RuntimeError("NLLB returned empty output")
        return translated


class UnifiedTranslator:
    def __init__(
        self,
        offline_root: Optional[str] = None,
        nllb_model_dir: Optional[str] = None,
    ) -> None:
        self.offline_root = os.path.expanduser(
            offline_root
            or os.environ.get("OFFLINE_TRANSLATORS_HOME", "~/Library/Application Support/OfflineTranslators")
        )
        model_dir = os.path.expanduser(nllb_model_dir or os.environ.get("NLLB_MODEL_DIR", os.path.join(self.offline_root, "nllb")))

        self.engines: Dict[str, TranslationEngine] = {
            "argos": ArgosEngine(self.offline_root),
            "nllb": NLLBEngine(model_dir=model_dir, compute_type="int8"),
        }

    def choose_engine(self, text: str, source_lang: str, mode: str) -> str:
        if mode == "fast":
            return "argos"
        if mode == "quality":
            return "nllb"
        if source_lang == "he":
            return "nllb"
        if len(text) > 200:
            return "nllb"
        return "argos"

    def translate(self, text: str, from_lang: str, to_lang: str, mode: str = "auto") -> TranslationResult:
        payload = text or ""
        if not payload.strip():
            raise ValueError("Text must not be empty")

        normalized_mode = normalize_mode(mode)
        target_lang = normalize_lang(to_lang, allow_auto=False)
        source_lang = normalize_lang(from_lang, allow_auto=True)
        if source_lang == "auto":
            source_lang = detect_language(payload)

        if source_lang == target_lang:
            return TranslationResult(
                text=payload,
                engine="none",
                source_lang=source_lang,
                target_lang=target_lang,
                elapsed_ms=0.0,
                fallback_used=False,
            )

        primary = self.choose_engine(payload, source_lang, normalized_mode)
        fallback = "argos" if primary == "nllb" else "nllb"
        attempts = [primary] + ([fallback] if normalized_mode == "auto" else [])

        first_error = None
        start = time.perf_counter()

        for idx, engine_name in enumerate(attempts):
            engine = self.engines[engine_name]
            try:
                translated = engine.translate(payload, source_lang, target_lang)
                elapsed_ms = (time.perf_counter() - start) * 1000.0
                return TranslationResult(
                    text=translated,
                    engine=engine_name,
                    source_lang=source_lang,
                    target_lang=target_lang,
                    elapsed_ms=elapsed_ms,
                    fallback_used=(idx > 0),
                )
            except Exception as exc:  # noqa: BLE001
                if first_error is None:
                    first_error = exc

        raise RuntimeError(f"All offline engines failed. First error: {first_error}")


_TRANSLATOR_SINGLETON: Optional[UnifiedTranslator] = None
_TRANSLATOR_LOCK = threading.Lock()


def get_translator() -> UnifiedTranslator:
    global _TRANSLATOR_SINGLETON
    if _TRANSLATOR_SINGLETON is not None:
        return _TRANSLATOR_SINGLETON
    with _TRANSLATOR_LOCK:
        if _TRANSLATOR_SINGLETON is None:
            _TRANSLATOR_SINGLETON = UnifiedTranslator()
    return _TRANSLATOR_SINGLETON


def translate_with_meta(text: str, from_lang: str, to_lang: str, mode: str = "auto") -> TranslationResult:
    return get_translator().translate(text=text, from_lang=from_lang, to_lang=to_lang, mode=mode)


def translate(text: str, from_lang: str, to_lang: str, mode: str = "auto") -> TranslationResult:
    return translate_with_meta(text=text, from_lang=from_lang, to_lang=to_lang, mode=mode)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Unified offline translator (Argos + NLLB CT2)")
    parser.add_argument("text", nargs="+", help="Text to translate")
    parser.add_argument("--from", dest="from_lang", default="auto", help="Source language: auto|he|en|ru")
    parser.add_argument("--to", dest="to_lang", required=True, help="Target language: he|en|ru")
    parser.add_argument("--mode", dest="mode", default="auto", choices=sorted(SUPPORTED_MODES))
    return parser


def main(argv: Optional[list[str]] = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    text = " ".join(args.text)
    try:
        result = translate(text=text, from_lang=args.from_lang, to_lang=args.to_lang, mode=args.mode)
    except Exception as exc:  # noqa: BLE001
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    suffix = " (fallback)" if result.fallback_used else ""
    print(f"Engine: {result.engine}{suffix}")
    print(f"Time: {result.elapsed_ms:.1f} ms")
    print(f"Result: {result.text}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
