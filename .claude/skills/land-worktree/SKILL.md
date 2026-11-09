---
name: land-worktree
description: Land, rebase or remove an Awaken agent worktree with `bash tools/agent.sh new|land|remove` without racing other lanes: the land lock, import after a rebase, `.uid` and `.import` noise, "Could not preload resource file", scratch files that block a land, and the shared stash. Use when about to run `agent.sh land`, when a land or rebase fails, when another lane's assets are missing in your checkout, or when cleaning a worktree up at the end of a lane.
---

# Landing a worktree

The protocol is `docs/agents.md` (rules 1-9, the harness). These are the rules the lanes learned the hard way.

1. **Take the lock, then land.** `../land.lock` (the lane name inside) is the queue for lands and windowed films.
   Take it atomically and wait in the same loop:
   `until ( set -o noclobber; echo <lane> > ../land.lock ) 2>/dev/null; do sleep 60; done`
   (a separate `ls` then `echo >` races). Delete it after the land passes or fails. One background wait is enough:
   several foreground waits in a row pile up.

2. **Rebase, import, tidy, then land.** `git rebase dev`, then `godot --headless --import --path .` in your
   worktree whenever the rebase brought files under `assets/` (your `.godot/` never imported them: every check then
   fails with "Could not preload resource file" / "Unable to open file ... .ctex", and a new sheet draws as a cream
   square with no error). `agent.sh land` imports in the dev checkout for you after a land that adds assets, not in
   yours before. After an import run `tidy` (the land does), or revert the `.import` line-ending noise yourself:
   `git checkout --` each `git ls-files -m` file whose `git diff --ignore-cr-at-eol` is empty, with git's stderr to
   `/dev/null` (it prints a CRLF warning per file). Leave your own assets out of that loop.

3. **Close the race window.** The full checks take ~15 min and dev moves meanwhile; the fast-forward then refuses.
   Once the full checks have passed on your commits, rebase, import and `land --quick` straight away (the autotest
   still runs). Land several small commits together when other lanes are busy. A background `land` prints other
   lanes' landings too: read `git log dev` for your own subjects before re-landing.

4. **`.uid` files.** Commit the `.uid` of every script you add. If the rebase refuses with "untracked working tree
   files would be overwritten" for `.uid` files Godot made locally that another lane has since committed, delete the
   local copies (same content) and rebase again. Scratch SceneTrees in `tests/` leave `.uid` files too: delete both.

5. **Scratch files block a land** (it needs a clean tree, untracked files included). List them in the common git
   dir's `info/exclude` (`git rev-parse --git-common-dir`), never in `.gitignore`. Never set uncommitted work aside
   with a copy-and-restore that runs while the land does: commit the WIP to a scratch branch, or keep it in the
   scratchpad and copy it in once the land has finished.

6. **The stash is shared by every worktree.** Never a bare `git stash` / `git stash pop` (you can pop another lane's
   changes, and a stash in an imported project brings back every `.import` file with CRLF noise). If you must:
   `git stash push -u -m <tag>`, note the SHA from `git stash list --format='%H %gs'`, `git stash apply <sha>`,
   then drop it by tag. A temporary WIP commit is simpler.

7. **Never commit, stage, checkout or reset in another checkout**, including `awaken/` (dev). A Godot run there
   leaves import noise (a uid rewritten in a `.png.import`): `git checkout --` that one file there, or run in your
   own worktree instead. Resolve rebase conflicts in your worktree keeping both sides' intent; if a refactor touched
   files a live lane is rewriting, `git checkout dev -- <their files>` and put back the few forwarders they call
   (grep `hero\.X` / `player\.X` in their files), since a missing one is a SCRIPT ERROR only when the bot reaches it.

8. **`remove <name>`** refuses over uncommitted tracked changes and untracked non-`.uid` files; "Permission denied"
   means a Godot run or editor still holds a file: close it and run `remove` again. Mid-lane stop order: land the part
   that is already green (same `breakers=` / `strings=`, every `[improv]` cell above 0), leave the rest as `- [ ]`
   lines in `ROADMAP.md` `## Now`.
