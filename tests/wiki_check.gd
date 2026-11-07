extends SceneTree
## The wiki's data is in sync with the code: tools/wiki_data.gd's build() against docs/wiki/data.js. A FAIL means a
## move, slot, breaker, rule or counter number changed and the wiki wasn't rebuilt: run `python tools/wiki.py`.
## Prints `[wiki] PASS/FAIL`.
## godot --headless --path . -s tests/wiki_check.gd

const DATA := "res://docs/wiki/data.js"


func _initialize() -> void:
	await process_frame
	var want: String = load("res://tools/wiki_data.gd").build()
	var have := FileAccess.get_file_as_string(DATA).replace("\r\n", "\n")
	if have == want:
		print("[wiki] PASS data.js matches the code (%d bytes)" % want.length())
	elif have == "":
		print("[wiki] FAIL %s is missing: run python tools/wiki.py" % DATA)
	else:
		var a := have.split("\n")
		var b := want.split("\n")
		var i := 0
		while i < mini(a.size(), b.size()) and a[i] == b[i]:
			i += 1
		print("[wiki] FAIL data.js is stale (first difference at line %d: %s): run python tools/wiki.py" % [i + 1,
			(b[i] if i < b.size() else "<end>").strip_edges()])
	quit(0)
