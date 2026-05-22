from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class YamlError(ValueError):
    pass


def load_yaml(path: Path) -> Any:
    return parse_yaml(path.read_text(), source=str(path))


def parse_yaml(text: str, *, source: str = "<string>") -> Any:
    lines: list[tuple[int, str, int]] = []
    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        if "\t" in raw_line[: len(raw_line) - len(raw_line.lstrip())]:
            raise YamlError(f"{source}:{line_no}: tabs are not supported")
        indent = len(raw_line) - len(raw_line.lstrip(" "))
        lines.append((indent, raw_line.strip(), line_no))

    if not lines:
        return {}

    value, index = _parse_block(lines, 0, lines[0][0], source)
    if index != len(lines):
        _, _, line_no = lines[index]
        raise YamlError(f"{source}:{line_no}: unexpected trailing content")
    return value


def dump_yaml(value: Any, *, indent: int = 0) -> str:
    return "\n".join(_dump_yaml_lines(value, indent)) + "\n"


def _parse_block(
    lines: list[tuple[int, str, int]],
    index: int,
    indent: int,
    source: str,
) -> tuple[Any, int]:
    if index >= len(lines):
        return {}, index

    current_indent, text, line_no = lines[index]
    if current_indent < indent:
        return {}, index
    if current_indent != indent:
        raise YamlError(f"{source}:{line_no}: expected indent {indent}, got {current_indent}")

    if text == "-" or text.startswith("- "):
        return _parse_list(lines, index, indent, source)
    return _parse_mapping(lines, index, indent, source)


def _parse_mapping(
    lines: list[tuple[int, str, int]],
    index: int,
    indent: int,
    source: str,
) -> tuple[dict[str, Any], int]:
    result: dict[str, Any] = {}

    while index < len(lines):
        current_indent, text, line_no = lines[index]
        if current_indent < indent:
            break
        if current_indent > indent:
            raise YamlError(f"{source}:{line_no}: unexpected indent {current_indent}")
        if text.startswith("- "):
            break

        key, raw_value = _split_key_value(text, source, line_no)
        if raw_value == "":
            index += 1
            if index >= len(lines) or lines[index][0] <= indent:
                result[key] = {}
            else:
                result[key], index = _parse_block(lines, index, lines[index][0], source)
        else:
            result[key] = _parse_scalar(raw_value)
            index += 1

    return result, index


def _parse_list(
    lines: list[tuple[int, str, int]],
    index: int,
    indent: int,
    source: str,
) -> tuple[list[Any], int]:
    result: list[Any] = []

    while index < len(lines):
        current_indent, text, line_no = lines[index]
        if current_indent < indent:
            break
        if current_indent != indent or not (text == "-" or text.startswith("- ")):
            break

        item_text = "" if text == "-" else text[2:].strip()
        if item_text == "":
            index += 1
            if index >= len(lines) or lines[index][0] <= indent:
                result.append(None)
            else:
                item, index = _parse_block(lines, index, lines[index][0], source)
                result.append(item)
            continue

        if _looks_like_key_value(item_text):
            key, raw_value = _split_key_value(item_text, source, line_no)
            item: dict[str, Any] = {}
            index += 1
            if raw_value == "":
                if index >= len(lines) or lines[index][0] <= indent:
                    item[key] = {}
                else:
                    item[key], index = _parse_block(lines, index, lines[index][0], source)
            else:
                item[key] = _parse_scalar(raw_value)

            while index < len(lines) and lines[index][0] > indent:
                nested, index = _parse_mapping(lines, index, lines[index][0], source)
                item.update(nested)
            result.append(item)
            continue

        result.append(_parse_scalar(item_text))
        index += 1

    return result, index


def _split_key_value(text: str, source: str, line_no: int) -> tuple[str, str]:
    if ":" not in text:
        raise YamlError(f"{source}:{line_no}: expected key: value")
    key, value = text.split(":", 1)
    key = key.strip()
    if not key:
        raise YamlError(f"{source}:{line_no}: empty keys are not supported")
    return key, value.strip()


def _looks_like_key_value(text: str) -> bool:
    if ":" not in text:
        return False
    key, _ = text.split(":", 1)
    return bool(key.strip()) and " " not in key.strip()


def _parse_scalar(raw_value: str) -> Any:
    value = raw_value.strip()
    if value in {"[]", "~"}:
        return [] if value == "[]" else None
    if value == "{}":
        return {}
    if value in {"true", "True"}:
        return True
    if value in {"false", "False"}:
        return False
    if value in {"null", "None"}:
        return None
    if (value.startswith('"') and value.endswith('"')) or (
        value.startswith("'") and value.endswith("'")
    ):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def _dump_yaml_lines(value: Any, indent: int) -> list[str]:
    pad = " " * indent
    if isinstance(value, dict):
        lines: list[str] = []
        for key, item in value.items():
            if _is_scalar(item):
                lines.append(f"{pad}{key}: {_format_scalar(item)}")
            elif isinstance(item, list) and not item:
                lines.append(f"{pad}{key}: []")
            elif isinstance(item, dict) and not item:
                lines.append(f"{pad}{key}: {{}}")
            else:
                lines.append(f"{pad}{key}:")
                lines.extend(_dump_yaml_lines(item, indent + 2))
        return lines

    if isinstance(value, list):
        lines = []
        for item in value:
            if _is_scalar(item):
                lines.append(f"{pad}- {_format_scalar(item)}")
            elif isinstance(item, dict):
                items = list(item.items())
                if not items:
                    lines.append(f"{pad}- {{}}")
                    continue
                first_key, first_value = items[0]
                if _is_scalar(first_value):
                    lines.append(f"{pad}- {first_key}: {_format_scalar(first_value)}")
                else:
                    lines.append(f"{pad}- {first_key}:")
                    lines.extend(_dump_yaml_lines(first_value, indent + 4))
                rest = dict(items[1:])
                if rest:
                    lines.extend(_dump_yaml_lines(rest, indent + 2))
            else:
                lines.append(f"{pad}-")
                lines.extend(_dump_yaml_lines(item, indent + 2))
        return lines

    return [f"{pad}{_format_scalar(value)}"]


def _is_scalar(value: Any) -> bool:
    return value is None or isinstance(value, (str, int, bool))


def _format_scalar(value: Any) -> str:
    if value is True:
        return "true"
    if value is False:
        return "false"
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value))
