## Steam Burst's cloud (Dash L H H L, ice into magma): a frozen foe goes off in the drawn steam cloud
## (designed_finish.steam). A forwarder for the callers (void_element, slapshot_fx).
##   ComicSteam.spawn(parent, spot)

const DESIGNED_FINISH := preload("res://scripts/designed_finish.gd")


static func spawn(parent: Node, spot: Vector3) -> Node3D:
	return DESIGNED_FINISH.steam(parent, spot)
