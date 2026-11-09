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
  `../awaken/vendor_src` (put a `.gdignore` in it first, or the import scans
  the FBX and `.blend` files and silently keeps old GLBs).
- `bash tools/agent.sh list` shows every worktree and how far its branch is
  ahead of or behind `dev`.

## Rules

1. **Work and commit only in your own worktree.** Never stage, commit, reset
   or stash in another agent's checkout, including `awaken/`. The stash is
   shared by every worktree: if you must stash, `git stash push -u -m <tag>`
   and `git stash apply <sha>`, never a bare `stash` / `pop`.
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
   each other. Copy your shots out straight after taking them. Films go in
   your own folder: `tests/string_film.gd -- --dir=<name>_before` (and
   `_after`) writes `user://<name>_before/`; the default `user://string_film/`
   is everyone's. Never touch Zak's `settings.cfg`, `records.cfg` or
   `altar.cfg`.
8. **Windowed Godot steals focus.** Only open it when Zak has said that's OK.
9. **The land lock.** `../land.lock` (the lane name inside) means a land or a
   windowed film is running. Take it atomically and wait in the same loop,
   `until ( set -o noclobber; echo <lane> > ../land.lock ) 2>/dev/null; do sleep 60; done`
   (a separate `ls` then `echo >` races), hold it through the land or the
   film, delete it when that passes or fails. One background wait is enough;
   don't chain several foreground waits on it.

## The harness (`tools/agent.sh`)

- `new <name>`: worktree `../awaken-<name>` on `agent/<name>` from dev, imported, line-ending noise dropped.
- `check [--quick]`: every test in its list (skipped if the file is gone), then the autotest twice (plain, then
  `--kit=full --room=pieces`), which must land every breaker, string, ending, kit slot and piece verb. Three
  timing tests are retried once on a FAIL (`RETRY` in agent.sh: `rhythm_check ice_block_check cool_pass_check`);
  a FAIL on both runs is real. Afterwards it restores files whose only change is line endings (`tidy`: the
  headless runs re-import, and Godot writes `.import` files LF while the checkout is CRLF). A `.gitattributes`
  `*.import eol=lf` rule was tried and left out: git still lists the rewritten files as modified.
- `land [--quick]`: tidy, refuse if dirty, rebase on dev, check, fast-forward dev; when the land adds files under
  `assets/`, it also imports them in the dev checkout (`.godot/` is ignored, so dev never saw them).
- `remove <name>`: drops line-ending noise, refuses over uncommitted changes and untracked files other than `.uid`, then
  `worktree remove --force` (untracked `.uid` files, `.godot/` and shots don't block it), deletes whatever Windows
  left ("Permission denied" from a file a Godot run still holds: it says so if a file is still locked; close it
  and run `remove` again), prunes, and deletes `agent/<name>` only when dev has every commit (otherwise it keeps it
  and says how many commits are not on dev).
- `list`: worktrees and how far each branch is ahead of / behind dev.

## When you're done

Land your work, then run `bash tools/agent.sh remove <name>`. This deletes
the worktree, and deletes the branch once it has been merged.

## Where the lessons live

The lane diaries that used to sit here are now rules, one place each:

- `.claude/skills/land-worktree/SKILL.md`: landing, rebasing, `--import` after a rebase, `.uid` conflicts, scratch files, the lock.
- `.claude/skills/windows-patching/SKILL.md`: editing CRLF GDScript from a shell on this machine (no heredocs, no `sed -i`).
- `.claude/skills/godot-headless-test/SKILL.md`: writing and fixing `tests/*_check.gd` and `agent.sh check` failures.
- `.claude/skills/film-and-judge/SKILL.md`: judging feel and look from `string_film`, the shot tests and contact sheets.
- `.claude/skills/perf-probe/SKILL.md`: reading `[perf]`, hunting a hitch, materials and shaders.
- `.claude/skills/bot-strings/SKILL.md`: `training_bot.BOT_STRINGS`, its tokens and the `[autotest]` counters.
- Gameplay and model lessons: the "Gotchas" sections of `docs/features/*.md` (training, fx-language, combo-breakers,
  camera, void-element, element-matrix, combo-guide, heretic-hero, comic-style).
