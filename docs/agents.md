# Working with several agents

Several Claude sessions can work on Awaken at once. Each agent gets its own
checkout and branch, commits its own work, and lands it on `dev` by
fast-forward, so no agent edits another's files or index.

## The layout

- `awaken/` is the **integration checkout**. It stays on `dev`, and nobody
  works in it. `agent.sh land` fast-forwards it.
- `awaken-<name>/` is one agent's git worktree, on branch `agent/<name>`.
  Make one with `bash tools/agent.sh new <name>`, which also imports the
  project. `vendor_src/` is gitignored, so copy assets from
  `../awaken/vendor_src`.
- `bash tools/agent.sh list` shows every worktree and how far its branch is
  ahead of or behind `dev`.

## Rules

1. **Work and commit only in your own worktree.** Never stage, commit, reset
   or stash in another agent's checkout, including `awaken/`.
2. **Commit small and often.** Use Conventional Commits (`feat:`, `fix:`,
   `chore:`, `docs:`, `refactor:`, `test:`, `perf:`). Don't add
   Co-Authored-By, Claude-Session or "Generated with" lines. Never push.
3. **Land when a piece works:** run `bash tools/agent.sh land` from your
   worktree. It does four things:
   - checks your worktree is clean;
   - rebases onto `dev`;
   - runs the headless checks (every PASS/FAIL test and the autotest;
     `--quick` runs the autotest only);
   - fast-forwards `dev`.

   If another agent landed first, the fast-forward refuses. Run `land` again.
4. **Merge conflicts are yours to resolve,** in your own worktree, during the
   rebase. Keep both sides' intent. The other side is already on `dev` and
   has passed the checks, so build on it rather than reverting it. If you
   can't tell what the other side meant, ask its agent (`SendMessage`; find
   it with `ListAgents`) or Zak. Don't guess at another feature's logic.
   Then run `git add`, `git rebase --continue`, and `land` again. The checks
   run after the rebase, so a bad resolution won't land.
5. **Hot files.** `scripts/player.gd`, `scripts/main.gd`, `CLAUDE.md` and
   `ROADMAP.md` change in almost every feature. Before a large refactor or
   move in one of them, message the other agents. Add new code in new
   functions and files rather than reshuffling existing ones. Add to
   `CLAUDE.md` and `ROADMAP.md` (new lines at the end of a section) rather
   than rewording other agents' lines.
6. **Rebase often** (`git rebase dev`) on long work, so conflicts stay small.
7. **Shared user data.** `user://` (`%APPDATA%/Godot/app_userdata/Awaken/`)
   is shared by every checkout, so screenshots from two agents can overwrite
   each other. Look at your shots straight after taking them. Never touch
   Zak's `settings.cfg`, `records.cfg` or `altar.cfg`.
8. **Windowed Godot steals focus.** Only open it when Zak has said that's OK.

## Lessons

- **`vendor_src/.gdignore` first.** Copying sources into a new worktree's `vendor_src/` without it makes `godot --import` scan the FBX and `.blend` files, fail on the blend importer, and silently skip re-importing your changed assets: the game keeps the old GLB and a shot looks unchanged. Check `.godot/imported/<name>.glb-*.md5` timestamps if a change doesn't show.
- **Extracted textures are never overwritten.** Godot keeps an existing `<name>_<material>.png` beside a GLB. Copy the new texture over it yourself.
- **Revert import noise in one loop:** for each `git ls-files -m` with an empty `git diff --ignore-cr-at-eol`, `git checkout` it. Leave your own assets out of the loop.
- **Meshy credits:** read the balance before and after each paid call (`GET /openapi/v1/balance`); the balance can also rise when Zak tops up, so count the change in `monthly_credits`.
- `tests/element_shots.gd -- --only=<combo>` films one string in about 20 s; the full run is about
  2.5 min. Iterate on one, then film all for the before/after. Copy `user://element_shots/` to your
  scratchpad straight away: other agents' runs overwrite it.
- Effects left standing carry into the next combo's frames (the frost spear lives 5 s and showed up
  under the ice cube shots), so read neighbouring sheets too when judging a lingering effect.
- A Python rewrite of a file on Windows keeps CRLF in text mode; check `git show --stat` after
  committing that only your lines changed.
- A `-s` SceneTree test can't name `Fx`, `ComicFx` or other class_name scripts
  that use the `Game` autoload: compiling it fails with "Identifier not found:
  Game" and floods errors. Use `get_root().get_node("Game")` and
  `load("res://scripts/fx.gd").crater(...)` at runtime.
- `billboard_mode` on a material drops the node's scale unless
  `billboard_keep_scale = true`: a scaled-up ink copy behind a billboard
  sprite hides exactly behind it.
- The soft VFX textures (`Fx.TEX` dot/scorch/star) fill well under half of
  their quad; a decal sized "radius" reads half that. For a cartoony hard
  shape use a flat mesh (CylinderMesh disc, ArrayMesh star) instead.
- Foes hit in the same physics frame are wave-delayed (`enemy.WAVE_STEP`); in
  a preview, hit the case you want to photograph on its own frame or its
  reaction hasn't started by the shot.
- `-s` timers windowed run long on the first frames (shader compiles): a
  "0.06 s later" screenshot is often 0.12+ s later. Print the numbers you're
  photographing alongside the shot.
- The scratchpad is shared between agents: keep your files in a subfolder.
  Name helper scripts uniquely too (`fxh2_sheet.py`): another agent's `sheet.py` replaced one mid-run.
- When splicing text into a doc with a script, check `git diff --stat` before committing: a slice
  that forgot the tail (`s[:j] + new` without `+ s[j:]`) silently deleted 70 lines.
- A visual that lives in a locked file (another lane's gameplay script) can often be driven from
  your own file by reading state: `ComicFx` watches `_move_id`, `_hits_done` and `breakers_landed`
  instead of adding hooks to void_element.gd.
- **Meshy REST from Blender:** retexture (`/openapi/v1/retexture`, 10 credits) and auto-rig (`/openapi/v1/rigging`, 5) both work on a GLB sent as a data URI or a task id; call them from the live Blender with `urllib` so the key stays there. Decimate first (rigging caps at 380k tris).
- **Second model, same kind:** a variant of a hero loads through a file map (`ComicLook.HERETIC_MODELS`) while keeping the kind name, so tones, clips and every `hero_kind()` check work unchanged. Cache shared materials per texture, not per material name.
- **"Parameter material is null" in the autotest** showed up on some seeds with the round-28 heretic as well as the chibi (seed 4: 20 lines). It predates round 29; not chased yet.

## When you're done

Land your work, then run `bash tools/agent.sh remove <name>`. This deletes
the worktree, and deletes the branch once it has been merged.
