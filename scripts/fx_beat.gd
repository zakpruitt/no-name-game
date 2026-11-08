extends RefCounted
## The effects language's shared timing, stepping and stamp (docs/features/fx-language.md). Every effect lane uses these
## numbers instead of its own: one beat structure (anticipation / hit / dissipate), one stepping rate (on twos), one
## ink weight, one way to put a designed sheet on screen (`stamp`, pooled).
##   const FX_BEAT := preload("res://scripts/fx_beat.gd")
##   FX_BEAT.stamp(parent, "war_cry", at, 3.0, "void", FX_BEAT.HIT)   # a sheet in the standard hit beat, pooled
##   var k := FX_BEAT.step(t)                                         # which on-twos drawing a hand-driven effect shows
##   node.scale = Vector3.ONE * FX_BEAT.settle(k)                     # the peak's overshoot, settling on twos

const DESIGNED := preload("res://scripts/designed_fx.gd")
const PAL := preload("res://scripts/fx_palette.gd")

# --- stepping --------------------------------------------------------------------------------------------------
const STEPS_PER_S := 12.0  # drawings change on twos (24 fps animation, a new drawing every other frame)
const STEP_S := 1.0 / STEPS_PER_S
const ONES_S := 1.0 / 24.0  # on ones: only the anticipation frame and a white-hot flash flicker this fast

# --- the beat (seconds; real time for the anticipation, game time after, so the hitstop holds the peak) ----------
const ANTIC_S := Vector2(0.033, 0.12)  # the anticipation: one 30 Hz frame for a hit, up to 0.12 s for a big wind-up
const PEAK_S := Vector2(0.07, 0.12)  # the peak drawing holds this long (plus whatever the hitstop adds)
const DISSIPATE_S := Vector2(0.18, 0.45)  # the dissolve after the peak (erosion eats it in its order)
const ERODE_FROM := Vector2(0.45, 0.6)  # erosion starts at this share of the life (never a plain alpha fade)
const PEAK_POP := 0.12  # extra scale on the anticipation->peak step, settling by the second step after
const SETTLE := [1.15, 1.0, 1.0]  # a hand-driven effect's scale per step from the peak (overshoot, settle)
## Life caps (real seconds; slow motion never holds a look longer than this).
const LIFE_HIT := 0.45  # every-hit effects (star, streaks, pop, war cry)
const LIFE_BEAT := 0.9  # a move's or a breaker's own beat (burst, rays, spread)
const LIFE_STANDING := 1.6  # floor marks and pools: and they fade when the next string's first hit lands

## The standard frame-time arrays (seconds per sheet frame). `HIT` for a 6-frame sheet: anticipation, peak, then on
## twos; `BEAT` holds the peak longer and slows its tail; `FLOOR` for a ground spread (slower, it lingers).
const HIT := [0.033, 0.075, 0.042, 0.042, 0.05, 0.06]
const BEAT := [0.035, 0.09, 0.07, 0.07, 0.08, 0.1]
const FLOOR := [0.04, 0.09, 0.12, 0.16, 0.2, 0.26]
const ERODE := {"HIT": Vector2(0.45, 1.0), "BEAT": Vector2(0.5, 1.0), "FLOOR": Vector2(0.55, 1.0)}

# --- ink (at the game camera, 1080p; fx_palette.PX_PER_M px a metre) ------------------------------------------------
const INK_PX := 2.0  # the outer ink line round any effect shape (PAL.LINE m)
const INK_PX_BIG := 3.0  # round a breaker-size shape (a burst, a block, a word); never more
const SHEET_INK_PX := 4.5  # in a sheet drawn at 384 px for a ~4 m quad (the quad is seen at ~1/2 to 1/3 its size)


## Which on-twos drawing `t` seconds in shows.
static func step(t: float) -> int:
	return floori(maxf(t, 0.0) * STEPS_PER_S)


## `t` held to the last twos boundary (drive a hand-built shape's pose from this, not from `t`).
static func on_twos(t: float) -> float:
	return float(step(t)) * STEP_S


## A hand-driven effect's scale at step `k` from its peak (overshoot, then settle).
static func settle(k: int) -> float:
	return float(SETTLE[clampi(k, 0, SETTLE.size() - 1)])


## Metres for `px` screen pixels at the game camera (ink widths, minimum sizes).
static func px_m(px: float) -> float:
	return px / PAL.PX_PER_M


## A frame-time array stretched to `life` seconds (keeps the anticipation and the peak, scales the tail).
static func times_for(base: Array, life: float) -> Array:
	var head: float = base[0] + base[1]
	var tail := 0.0
	for i in range(2, base.size()):
		tail += float(base[i])
	var k := maxf(life - head, 0.05) / maxf(tail, 0.001)
	var out: Array = [base[0], base[1]]
	for i in range(2, base.size()):
		out.append(float(base[i]) * k)
	return out


# --- the stamp: a designed sheet in the standard beat, pooled ------------------------------------------------------
const POOL_MAX := 12  # spare nodes kept per sheet
static var _pools := {}  # sheet -> Array of idle DESIGNED nodes
static var stamps := 0  # stamped (checks)
static var reused := 0  # of those, from the pool (checks)


## Put sheet `sheet` at `at`, `size` m, in `element`'s palette row, timed by `times` (HIT / BEAT / FLOOR or your own),
## the anticipation in real time (the peak lands on the hit's first frame and holds through the hitstop). Pooled: the
## node goes back to its sheet's pool when it ends, so a per-hit stamp allocates nothing after the first few.
## `opts`: erode (Vector2), pop (float), spin (float, rad; random in +-spin when `vary` is true), vary (bool),
## real_time (bool), standing (bool: fades on the next string's first hit; not pooled).
static func stamp(parent: Node, sheet: String, at: Vector3, size: float, element: String, times: Array = HIT,
		opts := {}) -> Node3D:
	if parent == null or not parent.is_inside_tree():
		return null
	stamps += 1
	var erode: Vector2 = opts.get("erode", ERODE.HIT if times == HIT else (ERODE.FLOOR if times == FLOOR else ERODE.BEAT))
	var standing: bool = opts.get("standing", false)
	var fx: Node3D = null
	if not standing:
		var pool: Array = _pools.get(sheet, [])
		while not pool.is_empty() and fx == null:
			var c: Variant = pool.pop_back()
			if is_instance_valid(c) and (c as Node).is_inside_tree() and (c as Node).get_parent() == parent:
				fx = c
		if fx != null:
			reused += 1
			fx.reuse(at, size, element, times, erode)
	if fx == null:
		fx = DESIGNED.spawn(parent, sheet, at, size, element, times, erode)
		if not standing:
			fx.recycle = _recycle
	fx.real_until = 1
	fx.real_time = opts.get("real_time", false)
	fx.pop = opts.get("pop", PEAK_POP)
	var spin: float = opts.get("spin", 0.0)
	if opts.get("vary", true):
		fx.vary(spin if spin > 0.0 else PI, true)
	else:
		fx.set_spin(spin)
	if standing:
		fx.standing = true
		DESIGNED.STANDING.add(fx)
	return fx


static func _recycle(fx: Node3D) -> bool:
	var pool: Array = _pools.get(fx.sheet, [])
	if pool.size() >= POOL_MAX:
		return false
	pool.append(fx)
	_pools[fx.sheet] = pool
	return true


## Forget the pools (a room rebuild frees their parent; Game.release-style cleanup).
static func release() -> void:
	_pools.clear()
