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
- **"Parameter material is null" in the autotest** came with the room seeds; after round 28 there is no seed and none of round 31's windowed autotests printed it.
- **The wall frame time lies here.** Zak's machine caps at 60 fps even with `--disable-vsync` (an empty project measures 16.67 ms), so `[perf] avg` stays ~16.4 ms whatever the game costs. Read `cpu` / `cpu_spikes` / `gpu` on the `[perf]` line.
- **Godot frees what nothing holds.** A `load("res://scripts/x.gd")` script and a StandardMaterial3D's generated shader are freed when their last user goes, and rebuilt (10-20 ms) on the next use. Effects that load scripts or make fresh materials each time hitched every time, not just the first. `warmup.gd` holds them; new effect materials need `--collect-shaders`.
- **`bake_mesh_from_current_skeleton_pose` is CPU skinning:** ~18 ms for the heretic. For a posed copy, share the mesh and skin with a new Skeleton3D holding the global poses.
- **`print` costs 2-10 ms with stdout piped** (agents' runs): one print in a hit path is a frame spike. Buffer autotest lines and print them at the end.
- **Per-function timing without the profiler:** a Python pass that renames each top-level `func f` to `__pc_f` and adds a wrapper adding `Time.get_ticks_usec()` deltas to `Engine.get_meta("pc")`, printed on spike frames, found every hitch in two runs. Revert with `git checkout scripts/`; don't commit it.
- **Never kill all godot processes** (`taskkill /IM godot*`): other agents run Godot too. Stop your own with TaskStop or its PID.

- `git rebase` onto a moved dev can refuse with "untracked working tree files would be overwritten" for
  `.uid` files Godot made locally that another agent has since committed. Delete the local copies (same
  content) and rebase again; commit the `.uid` of every new script you add.
- To find which effect is cluttering a shot, stub its function with an early `return`, reshoot that one
  combo (`--only=`) and compare. Two of round 29's three "worst" items turned out to be a different effect.
- **Killing Godot:** never `taskkill //IM godot.exe` (it hits other agents' runs and is refused); stop your own background command with TaskStop, and always wrap Godot in `timeout N`.
- **An eye or decal that draws nothing:** check face culling before position. A hand-built fan wound counter-clockwise is back-facing in Godot; set `cull_mode = CULL_DISABLED` like `heretic_form_fx.gd`.
- **"Parameter material is null" (10 lines, headless) has one reproducible cause:** `queue_free()` on a foe
  within a frame or so of hitting it (its flash / squash / ink tweens still running). Waiting ~1 s before freeing
  made it go away in `enemy_feel_check`; a foe killed and freed by the game mid-flash is the likely autotest source.
  **Cause (round 29 fx 4):** a MeshInstance3D freed with `Fx.flash`'s `material_overlay` still on it (the dummy's
  KayKit meshes; ten meshes, ten lines, no GDScript backtrace). `Fx._overlay` now takes it off on the root's
  `tree_exiting`; `tests/fx_free_check.gd` (in `agent.sh check`) catches engine errors with an `OS.add_logger` Logger.
- **To assert "no errors" in a headless test**, add a `Logger` subclass with `OS.add_logger` and count `_log_error`
  calls; engine errors with no script backtrace reach it too (the dummy renderer's material errors do).
- **Bisect a stray headless error by early `return`s** in the test body (one Godot run per marker, in a background
  loop), not by disabling features: it took four runs to pin the line that mattered.
- **A line-end `\\` typed into a Bash heredoc reached the Python edit script as one `\`**, so an edit whose old text
  held a GDScript line continuation never matched. Anchor the edit on the next line instead.
- **To film one move on one foe in a crowd**, take the others out of the `"enemies"` group for the call
  (`FOES.near` reads it) or film each on its own: three slams side by side were one purple blot.
- **Paused AnimationPlayer in a modifier or a check:** `current_animation` is "" while paused (use `assigned_animation`), and re-seeking a paused player in `heretic_shots` kept showing the old pose. Measure clip content from its tracks (`tests/contact_frames.gd` `track_pose`) in a check.
- **Changing a clip's keys under another lane's timing:** keep each contact frame, and run the lane's own measure (`tests/contact_frames.gd`) after every export; stepped keys make each drawing change a speed spike, so recovery steps must stay small.
- **GLB size is tracks, not keys:** each animation track costs a sampler, two accessors and buffer views in the GLB's JSON (about 280 bytes before any key), so 24 claw tracks on 40 clips added 280 KB of JSON alone. Drop tracks on clips nothing plays (grep `scripts/*.gd` for the clip names after the Ab_ mapping) before thinning keys.
- **Bash heredocs turn `\x00` into a real NUL** in a Python patch: the patched file became binary and grep stopped matching. Write byte literals as `bytes(1)`, or write the patch with the Write tool.

- **A string can strand the bot.** A lone L L H leaves the frost spear up for 5 s and any L or H press then vaults onto it,
  so the next strings never reached Collapse and Grounded; the autotest stayed green. Check `breakers=` / `moves=` against
  what the strings should reach, not only that it finished (`strings=N/N` now says every string played).
- **Prints in the autotest are frame spikes** (2-10 ms with stdout piped): bot lines go into `player.bot_log` / main's
  logs and print at the end.
- A tuning test should fail with the old number: flip the constant back, run it, see FAIL, flip it forward.
- **A `preload` in a `-s` test script compiles before the autoloads exist** ("Identifier not found: Game" in the
  preloaded script): `load()` effect scripts inside the test's functions instead.
- **The dev checkout can be mid-import** (another lane just landed GLBs): a windowed autotest there ran at 400-800 ms a
  frame with 0 hits. Measure a baseline in your own worktree with `git checkout <base> -- scripts tests`, then restore.
- **To find what a mystery shape on a sheet is**, copy the shot test, and at that shot print every visible
  MeshInstance3D near the hero with its parent's script and albedo; one run named the "ice glass" (a spirit tomahawk).
- **Splitting a big GDScript node (round 31, player.gd -> hero_*.gd):** the checks, the bot and void_grab read ~60 of
  the hero's fields and call ~30 underscored methods, so the state stays on the node and each new file is
  `extends RefCounted` with `static func f(hero: CharacterBody3D, ...)` (the void_element.gd pattern). Keep a one-line
  forwarder on the node for every name called from outside (grep `\.name\b` over scripts/ and tests/ first) and
  re-export read constants (`const MOVES := HERO_MOVES.MOVES` is a valid constant expression). The helpers never
  preload player.gd, so there is no preload cycle; they reach the enum and constants through the instance
  (`hero.State.LEAP`, `hero.CHARGE_TIME`).
- **Typed locals off an untyped `hero.x`:** `var t := hero._state_t * k` won't infer (Variant), so give the type. And
  never `var lock: Node3D = hero._aim_lock` before `is_instance_valid()`: assigning a freed object to a typed var is a
  runtime SCRIPT ERROR ("Trying to assign invalid previously freed instance"). Keep it `Variant` until checked.
- **Checks that grep the source:** comic_check scanned player.gd for `_play("clip")` lines. After a split it must scan
  the new files too (it now reads player.gd + `scripts/hero_*.gd`), or it passes while covering fewer clips.
- **Capture a baseline before the first edit, from a clean tree.** Each test is a fresh Godot reading the worktree's
  files: a baseline run in the background while you edit measures a mix. `git stash -u`, run, `git stash pop`.
- **Autotest run-to-run variance, same code:** breakers 5-7, max_combo 127-197, hits 163-227, `[rhythm]` beats within
  about 15 ms. rhythm_check's table is exact except `L1->L2 buffered ... hit` (218 or 221 ms, frame timing). Compare
  those, not the totals.
- **Facing in a shot:** comic and KayKit models face +Z, which is towards the game camera, so `model.rotation.y = PI` turns them away (`tests/enemy_lineup.gd` did this until round 29; from above you can't tell, from the front you see their backs). Leave it at 0 to face the camera.
- **Swapping a model the game spawns:** tests that build their own copy (`enemy_feel_check`, `enemy_feel_preview` built dummies from `Skeleton_Warrior`) keep the old model silently. Grep `tests/` for the old model name when you change what `main.gd` spawns.
- **Foe run speed vs feet (round 29):** measure, don't guess. Sample both foot bones over the run clip (seek + `force_update_all_bone_transforms`) and take the mean backward speed while a foot moves back in the lower half of its height; the kit's clips covered 1.2-30x less ground than `move_speed`. Chibi legs can't reach the stride, so widen it in Blender and speed the clip for the rest (`tests/foe_stride_check.gd`).
- **A test flag beats a temp edit for before/after:** `foe_shots.gd -- --bars / --side / --turn` made the bar and shadow comparisons one command each; for a const (FOE_SHADE_MATCH) a sed, run, sed back, then `git diff --stat` to prove it's restored.

- **Backslashes in heredocs reach Python halved here**: a backreference typed as two backslashes and 1 in a quoted
  heredoc patch arrived as one backslash, which Python read as a 0x01 byte and wrote into agent.sh. Write regex
  backreferences with the Edit tool, or build the backslash as `chr(92)` in the patch.
- **`sed -i` rewrites a CRLF file as LF** on this machine: harmless for git (autocrlf), but endings mix if a Python patch
  later writes bare newlines. Patch with Python reading in text mode and writing with `newline='\r\n'`.
- **A parse error in a script the main scene preloads hangs `--autotest`** until `timeout` (no quit, no `done` line):
  check a changed bot first with `godot --headless --check-only -s scripts/training_bot.gd` (an "Identifier not found:
  Game" there is fine).

## When you're done

Land your work, then run `bash tools/agent.sh remove <name>`. This deletes
the worktree, and deletes the branch once it has been merged.
- **Filming feel:** `tests/string_film.gd` (windowed, about a minute) films every bot string at 12 fps into
  `user://string_film/<string>/` with an INDEX.txt; copy it out at once. Grab frames into memory (half size) and write
  them while the bot walks between strings: saving a PNG mid-string stalls that frame and stretches the hitstop
  you are trying to film. Real-time 12 fps on a 60 Hz display lands on 83 or 100 ms; schedule from the film's start.
- **A SceneTree film can drive the autotest bot:** `training_bot.gd`.new() with `main` set, its shot flags set true and
  `_autotest_t` held at 0 each frame, so it never snaps over the shared `autotest_*.png` or quits the tree.
- **An effect's tween on scaled time outlives its string.** Hitstop and breaker slow motion stretch any `create_tween()`
  on a node; the combo-name callout hung 1-1.5 s into the next string. Film the gap between strings to see it.
