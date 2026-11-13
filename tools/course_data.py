"""Validate authored tables before writing any generated pages."""

import math
import re


def parse_rows(text, columns, *, optional=0, source="content"):
    if not text.strip():
        raise ValueError(f"{source}: empty content table")
    rows = []
    for line_number, line in enumerate(text.strip().splitlines(), 1):
        values = line.split("\t" if "\t" in line else "|")
        if not columns <= len(values) <= columns + optional:
            raise ValueError(
                f"{source}:{line_number}: expected {columns}–{columns + optional} "
                f"columns, got {len(values)} ({values[:2]!r})"
            )
        rows.append(values)
    return rows


def numeric_answer(value, context):
    # Python also accepts underscores and Unicode digits; browser number inputs do not.
    if not isinstance(value, str) or not re.fullmatch(
        r"[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?", value.strip()
    ):
        raise ValueError(f"{context}: invalid numeric answer {value!r}")
    answer = float(value)
    if not math.isfinite(answer):
        raise ValueError(f"{context}: answer must be finite, got {value!r}")
    return answer


def advanced_quiz(value, context):
    parts = value.split("::")
    if len(parts) != 3 or any(not part.strip() for part in parts):
        raise ValueError(f"{context}: expected question::answer::solution")
    numeric_answer(parts[1], context)
    return parts


def validate_content(base, fields, deep, core, projects):
    """Check cross-table identities and quiz assembly, including under python -O."""
    ids = set()
    for row in base + fields:
        ident = row[0]
        if not re.fullmatch(r"\d{2}", ident) or ident in ids:
            raise ValueError(f"Duplicate or invalid field id: {ident!r}")
        ids.add(ident)

    titles = set()

    def lesson(ident, title):
        if ident not in ids:
            raise ValueError(f"{title}: unknown field {ident!r}")
        identity = (ident, title)
        if not title.strip() or identity in titles:
            raise ValueError(f"Duplicate or empty lesson title: {identity!r}")
        titles.add(identity)
        return f"{ident} / {title}"

    for row in base:
        for index in range(2):
            context = lesson(row[0], row[5 + 7 * index])
            numeric_answer(row[10 + 7 * index], context)
            if len(row) > 20 + index:
                advanced_quiz(row[20 + index], context)
            else:
                raise ValueError(f"{context}: missing advanced quiz")

    normalized = list(deep)
    for row in core:
        if row[1] not in {"入门", "数学准备", "本科核心", "高阶选题"}:
            raise ValueError(f"{row[:3]!r}: unknown lesson stage")
        normalized.append([row[0]] + row[2:])
    for row in normalized:
        context = lesson(row[0], row[1])
        numeric_answer(row[8], context)
        if len(row) > 13 and "::" in row[13]:
            raise ValueError(f"{context}: advanced quiz placed in derivation column")
        if len(row) != 15:
            raise ValueError(f"{context}: missing advanced quiz column")
        advanced_quiz(row[14], context)

    project_ids = set()
    for row in projects:
        if row[0] not in ids or row[0] in project_ids:
            raise ValueError(f"Duplicate or unknown project field: {row[0]!r}")
        project_ids.add(row[0])
