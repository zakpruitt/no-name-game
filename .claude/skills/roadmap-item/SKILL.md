---
name: roadmap-item
description: Implement one Awaken change end to end — pick the top unchecked ROADMAP.md item (or the feature the user named), build it, verify with the autotest and screenshots, check it off, and make one Conventional Commit on dev. Use for "do the next roadmap item", "/loop" rounds, or any gameplay/feature request in this repo.
---

# One roadmap item, end to end

Read `CLAUDE.md` (layout, test flags) and `ROADMAP.md` first.

## 1. Pick
- The user's request, if they named one. Otherwise the first `- [ ]` in ROADMAP.md.
- If you notice a clearly more valuable fix, do that instead, and say why.
- If the item is ambiguous and the choice matters, ask. Otherwise pick the sensible default and note it.

## 2. Build
- Match the existing style: GDScript with explicit types where inference fails on Variants, comments at the same density, and tuning numbers in the existing tables (`MOVES`, `COMBOS`, `ENEMY_TYPES`, `ATTACKS`, `Upgrades.ALL`, …) with a short comment so Zak can tune them.
- Build scenes in code. Add a `--flag` and an autotest screenshot/stat for anything the bot can exercise.
- For multi-line GDScript edits from the shell, write a Python patch script into the scratchpad with Write; bash heredocs mangle `\n`.
- After adding assets or a `class_name`: `godot --headless --import --path .`.

## 3. Verify (every item)
- `godot --headless --path . -- --autotest`. It must print the `[autotest]` line with **no** `SCRIPT ERROR`/`ERROR`.
  - Filter noise with `grep -v "RID\|PagedAllocator\|Leaked instance\|instance_notify\|utilities.cpp"`.
  - A parse error makes Godot hang, so always wrap the call in `timeout 120`.
- Visual change: run `godot --path . -- --autotest` (plus the relevant flags), then Read the screenshot from `%APPDATA%/Godot/app_userdata/Awaken/` and look at it.
- Menus: open the pause menu in a windowed run (`tests/training_check.gd` windowed saves `training_pause.png`).
- All checks: `bash tools/agent.sh check`.
- **Save data:** never create or touch `settings.cfg`, `records.cfg` or `altar.cfg`.
  - The autotest already disables saving.
  - New test scripts must set `Game.save_hints = false`.

## 4. Record
- Check the item off in ROADMAP.md with a one-line note of what was done, including the numbers if any. Add follow-ups you discovered as new `- [ ]` items.
- Update CLAUDE.md if you added a flag, script, table or workflow.
- Add or update the feature's doc in `docs/features/` (template and index in its README): how it works, files, invariants, tuning, extending, tests. Do this for any feature that spans several files or has its own test.

## 5. Commit and report
- One Conventional Commit on `dev` (feat/fix/perf/docs/test/chore…).
  - No Co-Authored-By, Claude-Session or "Generated with" lines.
  - **Never push.**
- If the change is visually notable, send Zak the screenshot with SendUserFile.
- Tell him what changed and what you verified (paste the autotest stat that proves it), and flag anything you couldn't check (feel, audio, gamepad).
