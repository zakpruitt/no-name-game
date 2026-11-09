---
name: windows-patching
description: Edit Awaken's CRLF GDScript (and Markdown) files from a shell on this Windows machine without mangling them: the Edit tool first, Python patch scripts written with the Write tool and run with `python -I C:/...`, `newline=''` reads that write back the file's own ending, asserted replace counts, and no `sed -i` or bash heredocs. Use whenever a multi-line code edit, a scripted find-and-replace, a temporary constant flip or a bulk doc change is about to be made from Bash in this repo, or when a patch "did nothing", mixed line endings or git warns "LF will be replaced by CRLF".
---

# Patching files on this machine

Every `.gd`, `.md` and `.import` in the repo is CRLF; git's autocrlf hides that from the index but not from
your tools. Mixed endings make `git diff` show whole files, make `str.replace` miss, and make a check "pass" on
code that was never changed.

## The rules
1. **Use the Edit tool for any edit you can anchor** (it preserves the endings and fails loudly on a miss).
2. **Scripted edits are a `.py` file in your own scratchpad subfolder, written with the Write tool**, then run with
   `python -I C:/Users/.../patch.py` (a `C:/...` path: MSYS rewrites `/c/...` arguments, and not strings inside
   `python -c`; `-I` because the shared scratchpad has held an `inspect.py` that shadowed the stdlib and broke
   `import numpy` for everyone). Name helpers uniquely (`fxh2_sheet.py`): another lane's `sheet.py` replaced one mid-run.
3. **Never put code in a bash heredoc.** Here a heredoc eats line-end `\`, halves backslashes (a `\1` backreference
   arrived as byte 0x01 and went into agent.sh), turns `\x00` into a real NUL (the file became binary), and fails
   with "unexpected EOF while looking for matching `'`" once a Python body is long or holds apostrophes.
4. **Never `sed -i` a repo file.** It rewrites the file LF; a later Python patch then mixes endings, and `file x.gd`
   after every sed is more work than not using it.
5. **Read with `newline=''` and write back the file's own ending.** `open(p, newline='')` keeps `\r\n` in the text,
   so an `old` string typed with bare `\n` matches nothing and `str.replace` does not fail. Either normalise to `\n`,
   edit, and write back with the ending you detected, or write every inserted line with `\r\n`. Triple-quoted blocks
   with bare newlines put LF lines into a CRLF file (git: "LF will be replaced by CRLF").
6. **Assert the count.** `assert s.count(old) == 1` before replacing; a patch that `sys.exit`s on a missing anchor
   must write nothing, and a slice that forgets the tail (`s[:j] + new` without `+ s[j:]`) silently deletes the rest
   of the file. One run, one patch: a second no-op pair can drop the first, real one.
7. **`git diff --stat` after every patch run**, and `git show --stat` after the commit: only your lines changed, and
   no file flipped wholesale.
8. **`git checkout <file>` drops your uncommitted edits with the temporary one.** For an A/B of a constant (prove a
   check fails on the old value), commit first or copy the file aside, flip, run, restore from the copy. A flag on the
   test (`foe_shots -- --bars`) beats a temp edit when you will compare twice.

## Skeleton
```python
import sys
p = "C:/Users/pruit/Desktop/dev/awaken-<lane>/scripts/x.gd"
with open(p, encoding="utf-8", newline="") as f:
    s = f.read()
nl = "\r\n" if "\r\n" in s else "\n"
s = s.replace("\r\n", "\n")
old, new = "const FOO := 1.0\n", "const FOO := 1.5\n"
assert s.count(old) == 1, s.count(old)
s = s.replace(old, new)
with open(p, "w", encoding="utf-8", newline="") as f:
    f.write(s.replace("\n", nl))
```
Keep each lane's edits to a shared file (training_bot.gd, void_element.gd) as small named patch scripts: splitting
one patched file into several commits is then `git show HEAD:<file> > <file>`, rerun the earlier patch, `git add`,
copy the full file back.
