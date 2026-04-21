extends RefCounted

const IslandSpawnerScript = preload("res://scripts/islands/island_spawner.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var spawner = IslandSpawnerScript.new()
	spawner.spawn_outer_half_width = 28.0
	spawner.spawn_outer_half_depth = 42.0
	spawner.spawn_inner_half_width = 10.0
	spawner.spawn_inner_half_depth = 16.0

	seed(12345)

	var saw_left := false
	var saw_right := false
	var saw_front := false
	var saw_back := false

	for _index in range(240):
		var offset: Vector3 = spawner.generate_spawn_offset()
		if not spawner.is_in_spawn_band(offset):
			failures.append("generated island offset should stay inside the outer ring around the board")
			break
		if offset.x <= -spawner.spawn_inner_half_width:
			saw_left = true
		if offset.x >= spawner.spawn_inner_half_width:
			saw_right = true
		if offset.z <= -spawner.spawn_inner_half_depth:
			saw_front = true
		if offset.z >= spawner.spawn_inner_half_depth:
			saw_back = true

	if not saw_left:
		failures.append("island spawner should place islands on the left side of the board")
	if not saw_right:
		failures.append("island spawner should place islands on the right side of the board")
	if not saw_front:
		failures.append("island spawner should place islands in front of the board")
	if not saw_back:
		failures.append("island spawner should place islands behind the board")

	return failures
