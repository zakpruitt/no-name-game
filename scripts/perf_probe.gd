extends Node
## Times every node's _process and _physics_process for the autotest's `[perf]`
## line: two marker nodes run first and last in each pass (process_priority),
## and the gap between them is that pass's node work (scripts, and whatever
## they make the engine do: mesh builds, instancing). At the end of each frame
## it calls `on_frame(node_ms)`.
## The wall frame time alone can't show the cost: the display caps it (60 fps
## on Zak's machine even with vsync off), so a 3 ms frame and a 16 ms one
## look the same.

const FIRST := -1000000
const LAST := 1000000

var on_frame: Callable
var _ms := 0.0  # this frame's node work so far (physics steps + process)
var _t0 := 0


func _ready() -> void:
	for p: int in [FIRST, LAST]:
		var marker := _Marker.new()
		marker.probe = self
		marker.first = p == FIRST
		marker.process_priority = p
		marker.process_physics_priority = p
		add_child(marker)


func _mark(first: bool, physics: bool) -> void:
	var now := Time.get_ticks_usec()
	if first:
		_t0 = now
		return
	_ms += (now - _t0) / 1000.0
	if not physics:  # the process pass ends the frame
		var ms := _ms
		_ms = 0.0
		if on_frame.is_valid():
			on_frame.call(ms)


class _Marker extends Node:
	var probe: Node
	var first := false

	func _process(_delta: float) -> void:
		probe._mark(first, false)

	func _physics_process(_delta: float) -> void:
		probe._mark(first, true)
