extends RefCounted
## Saved run records (user://records.cfg): totals and personal bests across
## runs. main.gd submits each finished run; the title screen shows them and
## the run summary flags new bests.

const PATH := "user://records.cfg"
## Off in the autotest so bot runs don't overwrite real records.
static var enabled := true
## How many recent runs the title screen lists.
const RECENT := 5


## {runs, wins, best_room, best_combo, best_rank, best_juggle, fastest_win}
## (best_rank "" = none yet, fastest_win 0 = no win yet).
static func load_records() -> Dictionary:
	var r := {"runs": 0, "wins": 0, "best_room": 0, "best_combo": 0, "best_rank": "", "best_juggle": 0, "fastest_win": 0.0}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in r:
			r[key] = cfg.get_value("records", key, r[key])
	return r


## Record a finished run and return the keys it set new bests for.
## `run` has: victory, rooms, combo, rank, juggle, time, and for the recent
## list room (reached), seed, daily ("" or the date).
static func submit(run: Dictionary) -> Array[String]:
	var r := load_records()
	var bests: Array[String] = []
	r.runs += 1
	if run.victory:
		r.wins += 1
		if r.fastest_win <= 0.0 or run.time < r.fastest_win:
			r.fastest_win = run.time
			bests.append("fastest_win")
	for pair in [["best_room", "rooms"], ["best_combo", "combo"], ["best_juggle", "juggle"]]:
		if run[pair[1]] > r[pair[0]]:
			r[pair[0]] = run[pair[1]]
			bests.append(pair[0])
	if run.rank != "" and (r.best_rank == "" or rank_index(run.rank) < rank_index(r.best_rank)):
		r.best_rank = run.rank
		bests.append("best_rank")
	if enabled:
		var recent := recent_runs()
		recent.push_front({"victory": run.victory, "room": run.get("room", run.rooms), "rank": run.rank,
			"seed": run.get("seed", -1), "daily": run.get("daily", "")})
		var cfg := ConfigFile.new()
		for key in r:
			cfg.set_value("records", key, r[key])
		cfg.set_value("recent", "runs", recent.slice(0, RECENT))
		cfg.save(PATH)
	return bests


## The last RECENT runs, newest first: {victory, room, rank, seed, daily}.
static func recent_runs() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return []
	return cfg.get_value("recent", "runs", [])


## "Victory   rank S   seed 123" / "Fell in room 4   rank B   daily 2026-10-31".
static func recent_line(run: Dictionary) -> String:
	var parts: Array[String] = ["Victory" if run.victory else "Fell in room %d" % run.room]
	if run.rank != "":
		parts.append("rank " + run.rank)
	if run.daily != "":
		parts.append("daily " + run.daily)
	elif run.seed >= 0:
		parts.append("seed %d" % run.seed)
	return "   ".join(parts)


## One line for the title screen ("" before the first run).
static func summary_line() -> String:
	var r := load_records()
	if r.runs == 0:
		return ""
	var parts := ["Runs %d" % r.runs, "Wins %d" % r.wins, "Best room %d" % r.best_room,
		"Best combo %d" % r.best_combo]
	if r.best_rank != "":
		parts.append("Best rank %s" % r.best_rank)
	if r.fastest_win > 0.0:
		parts.append("Fastest win %s" % time_text(r.fastest_win))
	return "   ·   ".join(parts)


static func time_text(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## Position in Game.RANKS (0 = best).
static func rank_index(rank: String) -> int:
	for i in Game.RANKS.size():
		if Game.RANKS[i][0] == rank:
			return i
	return Game.RANKS.size()
