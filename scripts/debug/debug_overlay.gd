class_name DebugOverlay
extends Node

var wave_zones_visible := true
var stats_panel_visible := true
var wave_spawner = null
var steering_input = null

var _stats_label: Label = null
var _canvas: CanvasLayer = null


func _ready() -> void:
	set_process_unhandled_input(true)
	_build_stats_panel()


func _process(_delta: float) -> void:
	if _stats_label == null or not stats_panel_visible:
		return
	if wave_spawner == null:
		return

	var active_count := 0
	var large_count := 0
	var pool_size: int = wave_spawner.get_inactive_pool_size()
	for child in wave_spawner.get_children():
		if child is Area3D:
			active_count += 1
			if child.is_large:
				large_count += 1

	var furthest: float = wave_spawner._furthest_ahead_distance
	var large_ratio := float(large_count) / float(maxi(active_count, 1)) * 100.0
	var sensor_text := ""
	if steering_input != null:
		sensor_text = "\nGyro: (%.2f, %.2f, %.2f)\nAccel: (%.2f, %.2f, %.2f)" % [
			steering_input.gyro_raw.x, steering_input.gyro_raw.y, steering_input.gyro_raw.z,
			steering_input.accel_raw.x, steering_input.accel_raw.y, steering_input.accel_raw.z,
		]
	_stats_label.text = "Waves: %d active / %d pooled\nLarge: %d (%.0f%%)\nFurthest ahead: %.0fm%s\n[F1] Toggle zones  [F2] Toggle stats" % [active_count, pool_size, large_count, large_ratio, furthest, sensor_text]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			_toggle_wave_zones()
		elif event.keycode == KEY_F2:
			_toggle_stats_panel()


func _toggle_wave_zones() -> void:
	wave_zones_visible = not wave_zones_visible
	if wave_spawner == null:
		return
	for child in wave_spawner.get_children():
		if child.has_method("set_debug_visible"):
			child.set_debug_visible(wave_zones_visible)


func _toggle_stats_panel() -> void:
	stats_panel_visible = not stats_panel_visible
	if _canvas != null:
		_canvas.visible = stats_panel_visible


func _build_stats_panel() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 100
	add_child(_canvas)

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_canvas.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.size_flags_vertical = Control.SIZE_SHRINK_END
	margin.add_child(vbox)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 10
	bg.content_margin_right = 10
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	_stats_label.add_theme_stylebox_override("normal", bg)
	vbox.add_child(_stats_label)
