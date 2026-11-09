---
name: roadmap-item
description: Implement one Awaken change end to end — pick the first item under `## Now` in ROADMAP.md (or the feature the user named), build it, verify with the autotest and screenshots, check it off, commit on your agent branch and land with agent.sh. Use for "do the next roadmap item", "/loop" rounds, or any gameplay/feature request in this repo.
---

# One roadmap item, end to end

Read `CLAUDE.md` (layout, test flags) and `ROADMAP.md` first.

## 1. Pick
- The user's request, if they named one. Otherwise the first item under `## Now` / `### Open items` in ROADMAP.md (`### Zak's calls` are his decisions, not yours).
- If you notice a clearly more valuable fix, do that instead, and say why.
- If the item is ambiguous and the choice matters, ask. Otherwise pick the sensible default and note it.

## 2. Build
- Match the existing style: GDScript with explicit types where inference fails on Variants, comments at the same density, and tuning numbers in the existing tables (`hero_moves.MOVES` / `COMBOS`, `void_element.BREAKERS`, `enemy_types.TYPES`, `kit_slots`, …) with a short comment so Zak can tune them.
- Build scenes in code. Add a `--flag` and an autotest screenshot/stat for anything the bot can exercise.
- Multi-line GDScript edits from the shell: the Edit tool, or a Python patch script per the `windows-patching` skill (CRLF files; no heredocs, no `sed -i`).
- After adding assets or a `class_name`: `godot --headless --import --path .`.

## 3. Verify (every item)
- `godot --headless --path . -- --autotest`. It must print the `[autotest]` line with **no** `SCRIPT ERROR`/`ERROR`.
  - Filter noise with `grep -v "RID\|PagedAllocator\|Leaked instance\|instance_notify\|utilities.cpp"`.
  - A parse error makes Godot hang, so always wrap the call in `timeout 120`.
- Visual change: run `godot --path . -- --autotest` (plus the relevant flags), then Read the screenshot from `%APPDATA%/Godot/app_userdata/Awaken/` and look at it.
- Menus: open the pause menu in a windowed run (`tests/training_check.gd` windowed saves `training_pause.png`).
- All checks: `bash tools/agent.sh check`. It reruns `rhythm_check`, `ice_block_check` and `cool_pass_check` once on a
  FAIL (a frame's miss under load); a FAIL on both runs is real (`godot-headless-test` skill). For a change that must not change behaviour, run dev's autotest once too and compare
  `breakers=`, `strings=`, `endings=`, `moves=`, `casts=` and every `[improv]` line; `hits=`, `max_combo=` and the
  `[rhythm]` ms vary by a few run to run.
- Films go in your own folder (`tests/string_film.gd -- --dir=<name>_before`): `user://` is shared by every worktree.
- **Save data:** never create or touch `settings.cfg`, `records.cfg` or `altar.cfg`.
  - The autotest already disables saving.
  - New test scripts must set `Game.save_hints = false`.

## 4. Record
- Check the item off in ROADMAP.md (`## Now`) with a one-line note of what was done, including the numbers if any; add follow-ups you discovered as new `- [ ]` lines there, and one line for the round under `## History`.
- Update CLAUDE.md if you added a flag, script, table or workflow.
- Add or update the feature's doc in `docs/features/` (template and index in its README): how it works, files, invariants, tuning, extending, tests. Do this for any feature that spans several files or has its own test.

## 5. Commit and report
- Conventional Commits (feat/fix/perf/docs/test/chore…) on your agent branch in your own worktree, landed with
  `bash tools/agent.sh land`; then `bash tools/agent.sh remove <name>` (`docs/agents.md`, the `land-worktree` skill).
  - No Co-Authored-By, Claude-Session or "Generated with" lines.
  - **Never push.**
- If the change is visually notable, send Zak the screenshot with SendUserFile.
- Tell him what changed and what you verified (paste the autotest stat that proves it), and flag anything you couldn't check (feel, audio, gamepad).

## Effects are drawn, not assembled (round 43 b)
- A new or reworked combat effect is an authored flipbook (`tools/vfx_gen/gen_designed.py`, played by
  `scripts/designed_fx.gd`), not a set of runtime polygons. Steps: `docs/features/designed-fx.md` "Authoring a new
  effect", and every effect is held to `docs/features/fx-language.md`'s checklist.
- Judge size in `tests/string_film.gd`, not a close scratch shot: the fight framing pulls the camera out to about half (`film-and-judge` skill).
