# Feature docs

Technical notes on the features built so far: how each one works, where its
code lives, what it depends on, and how to change it without breaking it.
They're written for whoever (person or agent) works on the feature next.

`CLAUDE.md` is the map of the repo, and `ROADMAP.md` records what was done
and when. These docs cover what neither has room for: the design, the
invariants and the gotchas.

## Index

| Feature | Doc | Main code |
|---|---|---|
| Combo guide (next-input hints beside the hero) | [combo-guide.md](combo-guide.md) | `scripts/combo_guide.gd`, `player.route()` |

## Writing one

Add a doc when a feature spans several files, has rules that aren't obvious
from the code, or has a test of its own. Name it `<feature>.md` and add a row
to the index above. Use these sections, and skip any that don't apply:

1. **What it does**: the player-facing behaviour, in a few lines.
2. **Files**: each file and function involved, and its role.
3. **How it works**: the data flow, in the order things happen.
4. **Invariants**: what must stay true, and what breaks if it doesn't.
5. **Tuning**: the constants and tables, and what each one changes.
6. **Extending**: the steps for the likely next changes.
7. **Testing**: the commands, and what each one checks.
8. **Gotchas / open questions**

Name functions and constants rather than citing line numbers, because line
numbers go stale. Update the doc in the same commit as the code it describes.
