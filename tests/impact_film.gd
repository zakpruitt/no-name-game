extends "res://tests/string_film.gd"
## The impact lane's kill case (docs/feel-audit-2026-11-07d.md item 1), windowed: string_film with a live foe whose hp
## is set to `--kill-hp=N` (default 0.6) as the hero goes up into a breaker's hang, so the hang's next tick kills it
## under its kill frame and its bar shows the last sliver until then. Same flags as string_film:
##   godot --path . -s tests/impact_film.gd -- --spar=warrior --from=11 --to=11 --tail=1300 --dir=<name> [--kill-hp=N]

var _kill_hp := 0.6
var _set_for := -1  # the string the foe's hp was set in


func _grab() -> void:
	if _kill_hp == 0.6:
		for arg: String in OS.get_cmdline_user_args():
			if arg.begins_with("--kill-hp="):
				_kill_hp = float(arg.get_slice("=", 1))
	var spar: Node = _main.get_node_or_null("Spar")
	if spar != null and _set_for != _bot._bot_string and _p.state == _p.State.LEAP:
		var e: Variant = spar.foe
		if is_instance_valid(e) and (e as Node).is_in_group("enemies") and (e as Node3D).global_position.distance_to(_p.global_position) < 8.0:
			_set_for = _bot._bot_string
			e.hp = minf(e.hp, _kill_hp)
			e.last_hit_ms = Time.get_ticks_msec()  # (its bar shows, as after a real hit)
	super._grab()
