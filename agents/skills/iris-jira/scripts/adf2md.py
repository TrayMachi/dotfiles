#!/usr/bin/env python3
"""Convert a Jira work item's ADF description to Markdown.

Reads the output of `acli jira workitem view <KEY> --fields "*all" --json` on stdin
and writes a Markdown rendering of `fields.description` to stdout.

Usage:
    acli jira workitem view OTP-123 --fields "*all" --json | python3 scripts/adf2md.py

Only the description is rendered. Wrap with a header (key, summary, status, etc.)
upstream if you need one — the converter intentionally stays focused on the ADF body.
"""

import json
import sys


def _marks(text, ms):
    for m in ms or []:
        t = m.get("type")
        if t == "strong":
            text = f"**{text}**"
        elif t == "em":
            text = f"_{text}_"
        elif t == "code":
            text = f"`{text}`"
        elif t == "strike":
            text = f"~~{text}~~"
        elif t == "link":
            href = m.get("attrs", {}).get("href", "")
            text = f"[{text}]({href})"
    return text


def _inline(nodes):
    out = []
    for n in nodes or []:
        t = n.get("type")
        if t == "text":
            out.append(_marks(n.get("text", ""), n.get("marks")))
        elif t == "hardBreak":
            out.append("  \n")
        elif t in ("inlineCard", "link"):
            attrs = n.get("attrs", {})
            url = attrs.get("url") or attrs.get("href", "")
            out.append(f"<{url}>")
        elif t == "mention":
            out.append("@" + n.get("attrs", {}).get("text", "").lstrip("@"))
        elif t == "emoji":
            out.append(n.get("attrs", {}).get("shortName", ""))
        else:
            if n.get("content"):
                out.append(_inline(n["content"]))
    return "".join(out)


def _block(n, depth=0, list_prefix=None):
    t = n.get("type")
    content = n.get("content") or []
    if t == "doc":
        return "\n\n".join(filter(None, (_block(c) for c in content)))
    if t == "heading":
        lvl = n.get("attrs", {}).get("level", 1)
        return f"{'#' * lvl} {_inline(content)}"
    if t == "paragraph":
        return _inline(content)
    if t == "bulletList":
        return "\n".join(_block(c, depth, "- ") for c in content)
    if t == "orderedList":
        return "\n".join(_block(c, depth, f"{i + 1}. ") for i, c in enumerate(content))
    if t == "listItem":
        pad = "  " * depth
        parts = []
        for c in content:
            ct = c.get("type")
            if ct == "paragraph":
                parts.append(_inline(c.get("content") or []))
            elif ct in ("bulletList", "orderedList"):
                parts.append("\n" + _block(c, depth + 1))
            else:
                parts.append(_block(c, depth + 1))
        body = "".join(parts)
        return f"{pad}{list_prefix or '- '}{body}"
    if t == "codeBlock":
        lang = n.get("attrs", {}).get("language", "")
        return f"```{lang}\n{_inline(content)}\n```"
    if t in ("blockquote", "panel"):
        inner = "\n\n".join(_block(c) for c in content)
        return "\n".join("> " + line for line in inner.split("\n"))
    if t == "rule":
        return "---"
    if t in ("mediaSingle", "mediaGroup"):
        return "_[media]_"
    if t == "table":
        rows = []
        header_len = 0
        for i, row in enumerate(content):
            cells = []
            for c in row.get("content") or []:
                cc = (c.get("content") or [{}])[0].get("content") or []
                cells.append(_inline(cc))
            rows.append("| " + " | ".join(cells) + " |")
            if i == 0:
                header_len = len(cells)
        if rows and header_len:
            rows.insert(1, "| " + " | ".join(["---"] * header_len) + " |")
        return "\n".join(rows)
    return _inline(content)


def main():
    data = json.load(sys.stdin)
    doc = data.get("fields", {}).get("description")
    if not doc:
        return
    print(_block(doc))


if __name__ == "__main__":
    main()
