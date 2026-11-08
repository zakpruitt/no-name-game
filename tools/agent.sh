#!/usr/bin/env bash
# One git worktree + branch per agent, landed on dev by fast-forward only.
#
#   tools/agent.sh new <name>          worktree ../awaken-<name> on branch agent/<name> (from dev), imported
#   tools/agent.sh check [--quick]     headless checks in the current checkout (PASS/FAIL tests + autotest)
#   tools/agent.sh land [--quick]      from inside a worktree: rebase onto dev, check, fast-forward dev
#   tools/agent.sh remove <name>       delete the worktree (even over untracked .uid / import files) and its merged branch
#   tools/agent.sh list                worktrees and how far each branch is ahead of / behind dev
#
# Landing never overwrites anyone: the rebase stops on conflicts for this
# agent to resolve in its own worktree, and dev only moves by fast-forward,
# so if another agent landed first the merge refuses and you land again.
set -euo pipefail

die() { echo "agent.sh: $*" >&2; exit 1; }
root() { git rev-parse --show-toplevel; }
# The checkout that has dev (the integration checkout, normally ../awaken).
dev_dir() {
	git worktree list --porcelain | awk '/^worktree /{w=substr($0,10)} /^branch refs\/heads\/dev$/{print w}'
}
# Godot's import rewrites .import files with LF line endings; with autocrlf
# git then reports them changed though the content is the same. Restore any
# file whose only difference is line endings.
tidy() {
	local real f
	real=$(git diff --ignore-cr-at-eol --name-only 2>/dev/null)
	for f in $(git ls-files -m 2>/dev/null); do
		grep -qxF "$f" <<< "$real" || git checkout -q -- "$f" 2>/dev/null
	done
}
godot_run() { timeout "$1" godot --headless --path "$(root)" "${@:2}" < /dev/null 2>&1 \
	| grep -v "RID\|PagedAllocator\|Leaked instance\|instance_notify\|utilities.cpp" || true; }

# Timing checks that can miss by a frame when other Godot runs load the machine
# (rhythm_check "L1 hands over to L2 sooner on a hit (224 < 233 ms)"): rerun once
# before failing. A real regression fails both runs.
# ice_block_check: the dummy's hit-freeze shudder put 4-16 body vertices 0.05-0.08 m past its block in 3 of 9 runs
# (round 51; 0 of 6 run alone).
RETRY="rhythm_check ice_block_check"

check() {
	local quick=${1:-}
	local fail=0 out
	local tests=(void_arm_check guide_check training_check prompt_follow_check move_list_check comic_check hitstop_check camera_feel_check impact_frame_check trail_check rhythm_check fx_free_check foe_stride_check hero_stride_check fx_sleek_check lean_spike_check prince_check ice_block_check breaker_spectacle_check counter_check spar_check kit_check lava_leash_check cool_pass_check cool3_check cool4_check env_target_check env_piece_check env_breaker_check rooms_check wiki_check input_snap_check)
	[ "$quick" = "--quick" ] && tests=()
	for t in "${tests[@]}"; do
		[ -f "$(root)/tests/$t.gd" ] || continue
		out=$(godot_run 180 -s "tests/$t.gd")
		if [[ " $RETRY " == *" $t "* ]] && echo "$out" | grep -q "\] FAIL"; then
			echo "retry $t (timing check, can flake under load)"; out=$(godot_run 180 -s "tests/$t.gd")
		fi
		if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error\|\] FAIL" || ! echo "$out" | grep -q "PASS"; then
			echo "FAIL  $t"; echo "$out" | grep "FAIL\|SCRIPT ERROR\|Parse Error" | head -5; fail=1
		else
			echo "ok    $t"
		fi
	done
	# The base kit in the plain room, then every kit upgrade on (scripts/kit.gd: --kit=full plays the demoted moves'
	# strings too) in the room with pieces (round 52: --room=pieces plays every plain string there, then the pieces'
	# strings by their pieces; folded into the second run rather than a third, ~3 min each).
	for args in "--autotest" "--autotest --kit=full --room=pieces"; do
		# shellcheck disable=SC2086
		out=$(godot_run 300 -- $args)
		if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error" || ! echo "$out" | grep -q "\[autotest\] done"; then
			echo "FAIL  $args"; echo "$out" | grep "FAIL\|SCRIPT ERROR\|Parse Error" | sort | uniq -c | head -5; fail=1
		elif ! echo "$out" | grep -q "\[autotest\] done.* breakers=\([0-9]\+\)/\1 .* strings=\([0-9]\+\)/\2 endings_n=\([0-9]\+\)/\3 "; then
			# the bot starts every string from the same spots (training_bot BOT_SPOT): every breaker, string and window
			# ending (each BREAKERS name and its `alt`'s) must land
			echo "FAIL  $args (not every breaker / string / ending)"; echo "$out" | grep "\[autotest\] done" | grep -o " breakers=[0-9/]* \| strings=[0-9/]* \| endings_n=[0-9/]* "; fail=1
		elif ! echo "$out" | grep -q "\[kit\] slots=\([0-9]\+\)/\1 windows=\([0-9]\+\)/\2 upgrades=\([0-9]\+\)/\3 "; then
			# every kit slot has a bot string that lands its moves, every window an ending, every upgrade on its string
			# (training_bot.kit_report)
			echo "FAIL  $args (not every kit slot / window / upgrade)"; echo "$out" | grep "\[kit\]"; fail=1
		elif [[ "$args" == *--room=pieces* ]] && ! echo "$out" | grep -q "^\[env\] .* pieces=\([0-9]\+\)/\1 uproot=[1-9][0-9]* keg=[1-9][0-9]* frost_wall=[1-9][0-9]* live_floor=[1-9][0-9]* conduct=[1-9][0-9]* gallows=[1-9][0-9]* ice_rink=[1-9][0-9]* brazier_spill=[1-9][0-9]*"; then
			# the room with pieces: the bot touches every counted piece and plays every built verb at least once
			# (env_piece.report: pieces=N/N and each BUILT verb's count)
			echo "FAIL  $args (not every piece / verb)"; echo "$out" | grep "^\[env\]" | grep -o "pieces=.*"; fail=1
		else
			echo "ok    $args"
		fi
	done
	tidy  # (the runs re-import: drop line-ending-only .import diffs)
	return $fail
}

cmd=${1:-}
case "$cmd" in
new)
	name=${2:-}; [ -n "$name" ] || die "usage: new <name>"
	main=$(dev_dir); [ -n "$main" ] || die "no checkout has dev"
	dir="$(dirname "$main")/awaken-$name"
	[ -e "$dir" ] && die "$dir already exists"
	git -C "$main" worktree add -b "agent/$name" "$dir" dev
	echo "importing (first time takes a minute or two)..."
	timeout 600 godot --headless --import --path "$dir" > /dev/null 2>&1 || true
	(cd "$dir" && tidy)
	echo "ready: cd \"$dir\"  (branch agent/$name)"
	;;
check)
	check "${2:-}" && echo "checks PASS" || { echo "checks FAIL"; exit 1; }
	;;
land)
	quick=${2:-}
	branch=$(git rev-parse --abbrev-ref HEAD)
	[[ "$branch" == agent/* ]] || die "run land from an agent worktree (on $branch)"
	tidy
	[ -z "$(git status --porcelain)" ] || die "commit or drop your changes first (git status)"
	main=$(dev_dir); [ -n "$main" ] || die "no checkout has dev"
	if ! git rebase dev; then
		die "rebase stopped on conflicts: resolve them here (keep both sides' intent; ask the owning agent if unsure), git add, git rebase --continue, then land again"
	fi
	if [ "$(git rev-list --count dev..HEAD)" = 0 ]; then
		echo "nothing to land: $branch is already in dev"; exit 0
	fi
	check "$quick" || die "checks failed: fix on $branch, then land again"
	before=$(git -C "$main" rev-parse HEAD)
	if ! git -C "$main" merge --ff-only "$branch"; then
		die "dev moved (another agent landed) or the dev checkout has local edits on the same files: land again"
	fi
	echo "landed on dev: $(git log --oneline -1)"
	# New assets were only imported in this worktree (.godot/ is ignored): import them in the dev checkout too,
	# or the game there fails to preload them ("Unable to open file ... .ctex").
	if git diff --name-only --diff-filter=A "$before" HEAD -- assets | grep -qv '[.]import$'; then
		echo "new assets: importing in $main"
		(cd "$main" && godot --headless --path . --import >/dev/null 2>&1; tidy) || echo "import in $main failed: run godot --headless --path . --import there"
	fi
	;;
remove)
	name=${2:-}; [ -n "$name" ] || die "usage: remove <name>"
	main=$(dev_dir); [ -n "$main" ] || die "no checkout has dev"
	dir="$(dirname "$main")/awaken-$name"
	[ "$(cd "$main" && pwd -P)" != "$(cd "$dir" 2>/dev/null && pwd -P)" ] || die "refusing to remove the dev checkout"
	if [ -d "$dir" ]; then
		(cd "$dir" && tidy) 2>/dev/null || true
		if [ -n "$(git -C "$dir" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
			git -C "$dir" status --short --untracked-files=no | head -5
			die "$dir has uncommitted changes to tracked files: commit or drop them first"
		fi
		# Untracked files that aren't Godot's .uid leftovers may be work nobody committed yet.
		left=$(git -C "$dir" ls-files --others --exclude-standard 2>/dev/null | grep -v '\.uid$' || true)
		if [ -n "$left" ]; then
			echo "$left" | head -5
			die "$dir has untracked files (above): commit or delete them first"
		fi
		# --force: .uid files and ignored leftovers (.godot/, shots) don't block it.
		git -C "$main" worktree remove --force "$dir" 2>/dev/null || true
		# Windows: a file still held open (a Godot run, an editor) gives "Permission denied"; delete what's left.
		[ -d "$dir" ] && { rm -rf "$dir" 2>/dev/null || cmd //c rmdir /s /q "$(cygpath -w "$dir" 2>/dev/null || echo "$dir")" > /dev/null 2>&1 || true; }
		[ -d "$dir" ] && echo "agent.sh: could not delete all of $dir (a program holds a file in it); close it and delete the folder"
	fi
	git -C "$main" worktree prune
	if git -C "$main" show-ref -q --verify "refs/heads/agent/$name"; then
		if git -C "$main" merge-base --is-ancestor "agent/$name" dev; then
			git -C "$main" branch -D "agent/$name"
		else
			echo "agent.sh: kept branch agent/$name: $(git -C "$main" rev-list --count dev..agent/$name) commit(s) not on dev (git branch -D agent/$name to drop them)"
		fi
	fi
	;;
list)
	git worktree list
	for b in $(git for-each-ref --format='%(refname:short)' refs/heads/agent/); do
		echo "$b: $(git rev-list --count dev.."$b") ahead, $(git rev-list --count "$b"..dev) behind dev"
	done
	;;
*)
	sed -n '2,13p' "$0"
	;;
esac
