"""List GDScript names nothing uses: functions, top-level consts / vars / signals / enums in scripts/
and tests/ whose name appears nowhere else as a word.

    python tools/dead_refs.py            # names with no use in code (scripts/, tests/, scenes/, tools/*.sh)
    python tools/dead_refs.py --docs     # also list names only docs mention (kept: a doc points at them)

A "use" is any whole-word match outside the defining line and outside comments (a name only a comment in code
mentions is dead; the docs are the place to name it), strings included, so `has_method("x")`,
`call("x")`, `set(key, ...)` from a spec dictionary and the bot's string tokens all count. Godot's
virtuals (_ready, _process, ...) are skipped. The tool only lists; delete by hand, then rerun the checks
(`bash tools/agent.sh check`): a name built at run time ("_on_" + id) would show here and still be live.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CODE_DIRS = ["scripts", "tests", "scenes", "shaders"]
CODE_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".cfg"}
DOC_GLOBS = ["docs/**/*.md", "*.md", ".claude/**/*.md"]
VIRTUALS = {
    "_ready", "_process", "_physics_process", "_input", "_unhandled_input", "_unhandled_key_input",
    "_shortcut_input", "_gui_input", "_draw", "_init", "_notification", "_enter_tree", "_exit_tree",
    "_get", "_set", "_get_property_list", "_to_string", "_initialize", "_finalize", "_static_init",
    "_get_configuration_warnings", "_validate_property", "_can_drop_data", "_drop_data", "_get_drag_data",
    "_has_point", "_make_custom_tooltip", "_integrate_forces", "_iter_init", "_iter_next", "_iter_get",
}
DEF = re.compile(r"^(?P<indent>\s*)(?:static\s+)?(?:@\w+(?:\([^)]*\))?\s+)*"
                 r"(?P<kind>func|const|var|signal|enum)\s+(?P<name>[A-Za-z_]\w*)")


def code_files():
    for d in CODE_DIRS:
        for p in (ROOT / d).rglob("*"):
            if p.suffix in CODE_EXT:
                yield p
    yield from (ROOT / "tools").glob("*.sh")


def strip_comment(line: str) -> str:
    """The line without its `#` comment (a `#` inside a string stays)."""
    quote = ""
    for i, ch in enumerate(line):
        if quote:
            if ch == quote and line[i - 1] != "\\":
                quote = ""
        elif ch in "\"'":
            quote = ch
        elif ch == "#":
            return line[:i]
    return line


def main() -> None:
    show_docs = "--docs" in sys.argv
    texts = {p: p.read_text(encoding="utf-8", errors="replace") for p in code_files()}
    docs = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                     for g in DOC_GLOBS for p in ROOT.glob(g))
    defs = []
    for p, text in texts.items():
        if p.suffix != ".gd":
            continue
        for i, line in enumerate(text.splitlines(), 1):
            m = DEF.match(line)
            if not m or m["name"] in VIRTUALS:
                continue
            if m["kind"] != "func" and m["indent"]:
                continue  # a local or an inner class's field: too noisy to call
            defs.append((p, i, m["kind"], m["name"], line))
    words: dict[str, int] = {}
    for p, text in texts.items():
        if p.suffix in (".gd", ".sh"):
            text = "\n".join(strip_comment(line) for line in text.splitlines())
        for w in re.findall(r"[A-Za-z_]\w*", text):
            words[w] = words.get(w, 0) + 1
    dead, doc_only = [], []
    for p, i, kind, name, line in defs:
        uses = words.get(name, 0) - len(re.findall(rf"\b{re.escape(name)}\b", strip_comment(line)))
        if uses > 0:
            continue
        rel = p.relative_to(ROOT).as_posix()
        if re.search(rf"\b{re.escape(name)}\b", docs):
            doc_only.append(f"{rel}:{i}  {kind} {name}")
        else:
            dead.append(f"{rel}:{i}  {kind} {name}")
    print(f"[dead_refs] {len(dead)} unreferenced (no code, no doc):")
    for d in dead:
        print("  " + d)
    if show_docs:
        print(f"[dead_refs] {len(doc_only)} only named in docs (kept):")
        for d in doc_only:
            print("  " + d)
    else:
        print(f"[dead_refs] {len(doc_only)} more only named in docs (--docs lists them)")


if __name__ == "__main__":
    main()
