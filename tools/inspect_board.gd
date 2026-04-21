extends SceneTree


func _init() -> void:
	var scene = load("res://assets/board.glb")
	if scene == null:
		push_error("failed to load board.glb")
		quit(1)
		return

	var root = scene.instantiate()
	_print_tree(root, 0)
	quit(0)


func _print_tree(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	var line := "%s%s <%s>" % [indent, node.name, node.get_class()]
	if node is Node3D:
		line += " pos=%s scale=%s rot=%s" % [str(node.position), str(node.scale), str(node.rotation_degrees)]
	if node is VisualInstance3D:
		line += " aabb=%s" % [str(node.get_aabb())]
	print(line)
	for child in node.get_children():
		_print_tree(child, depth + 1)
