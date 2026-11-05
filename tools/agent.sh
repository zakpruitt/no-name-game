#!/usr/bin/env bash
# One git worktree + branch per agent, landed on dev by fast-forward only.
#
#   tools/agent.sh new <name>          worktree ../awaken-<name> on branch agent/<name> (from dev), imported
#   tools/agent.sh check [--quick]     headless checks in the current checkout (PASS/FAIL tests + autotest)
#   tools/agent.sh land [--quick]      from inside a worktree: rebase onto dev, check, fast-forward dev
#   tools/agent.sh remove <name>       delete the worktree and its (merged) branch
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
	for f in $(git ls-files -m); do
		grep -qxF "$f" <<< "$real" || git checkout -q -- "$f"
	done
}
godot_run() { timeout "$1" godot --headless --path "$(root)" "${@:2}" < /dev/null 2>&1 \
	| grep -v "RID\|PagedAllocator\|Leaked instance\|instance_notify\|utilities.cpp" || true; }

check() {
	local quick=${1:-}
	local fail=0 out
	local tests=(void_arm_check guide_check training_check prompt_follow_check move_list_check comic_check hitstop_check camera_feel_check impact_frame_check trail_check rhythm_check fx_free_check foe_stride_check hero_stride_check)
	[ "$quick" = "--quick" ] && tests=()
	for t in "${tests[@]}"; do
		[ -f "$(root)/tests/$t.gd" ] || continue
		out=$(godot_run 180 -s "tests/$t.gd")
		if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error\|\] FAIL" || ! echo "$out" | grep -q "PASS"; then
			echo "FAIL  $t"; echo "$out" | grep "FAIL\|SCRIPT ERROR\|Parse Error" | head -5; fail=1
		else
			echo "ok    $t"
		fi
	done
	for args in "--autotest"; do
		# shellcheck disable=SC2086
		out=$(godot_run 180 -- $args)
		if echo "$out" | grep -q "SCRIPT ERROR\|Parse Error" || ! echo "$out" | grep -q "\[autotest\] done"; then
			echo "FAIL  $args"; echo "$out" | grep "FAIL\|SCRIPT ERROR\|Parse Error" | sort | uniq -c | head -5; fail=1
		elif ! echo "$out" | grep -q "\[autotest\] done.* breakers=\([0-9]\+\)/\1 .* strings=\([0-9]\+\)/\2 "; then
			# the bot starts every string from the same spots (training_bot BOT_SPOT): every breaker and string must land
			echo "FAIL  $args (not every breaker / string)"; echo "$out" | grep "\[autotest\] done" | grep -o " breakers=[0-9/]* \| strings=[0-9/]* "; fail=1
		else
			echo "ok    $args"
		fi
	done
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
	if ! git -C "$main" merge --ff-only "$branch"; then
		die "dev moved (another agent landed) or the dev checkout has local edits on the same files: land again"
	fi
	echo "landed on dev: $(git log --oneline -1)"
	;;
remove)
	name=${2:-}; [ -n "$name" ] || die "usage: remove <name>"
	main=$(dev_dir)
	dir="$(dirname "$main")/awaken-$name"
	git -C "$main" worktree remove "$dir"
	git -C "$main" branch -d "agent/$name"
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
