class_name WaveDebugPanel
extends CanvasLayer

signal param_changed(param_name: String, value: float)

var wave_spawner = null
var sea = null
var _paused := false
var _stats_label: Label = null


func _ready() -> void:
	layer = 100
	_build_panel()


func _process(_delta: float) -> void:
	_update_stats()


func is_paused() -> bool:
	return _paused


func _update_stats() -> void:
	if _stats_label == null or wave_spawner == null:
		return

	var active_count := 0
	var large_count := 0
	var pool_size: int = wave_spawner.get_inactive_pool_size()
	for child in wave_spawner.get_children():
		if child is Area3D:
			active_count += 1
			if child.is_large:
				large_count += 1

	var large_ratio := float(large_count) / float(maxi(active_count, 1)) * 100.0
	var furthest_ahead: float = wave_spawner._furthest_ahead_distance
	_stats_label.text = "Active: %d | Pooled: %d | Large: %d (%.0f%%)\nFurthest: %.0fm | %s" % [active_count, pool_size, large_count, large_ratio, furthest_ahead, "PAUSED" if _paused else "RUNNING"]


func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var panel_vbox := VBoxContainer.new()
	panel_vbox.add_theme_constant_override("separation", 6)
	margin.add_child(panel_vbox)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 18)
	_add_bg(_stats_label)
	panel_vbox.add_child(_stats_label)

	_add_slider(panel_vbox, "wave_speed", "Wave Speed", 0.1, 3.0, 1.0)
	_add_slider(panel_vbox, "wave_amplitude", "Wave Amplitude", 0.05, 1.0, 0.3)
	_add_slider(panel_vbox, "large_chance", "Large Wave %", 0.0, 1.0, 0.28)
	_add_slider(panel_vbox, "spawn_distance", "Spawn Distance", 30.0, 200.0, 100.0)

	var pause_btn := Button.new()
	pause_btn.text = "Pause [Space]"
	pause_btn.pressed.connect(_toggle_pause)
	panel_vbox.add_child(pause_btn)

	var info := Label.new()
	info.text = "[F] Toggle follow mode | [Space] Pause | Click+Drag to orbit"
	info.add_theme_font_size_override("font_size", 14)
	info.modulate.a = 0.7
	panel_vbox.add_child(info)


func _add_slider(parent: VBoxContainer, id: String, label_text: String, min_val: float, max_val: float, default: float) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(120.0, 0.0)
	label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = 0.01
	slider.value = default
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(200.0, 0.0)
	hbox.add_child(slider)

	var val_label := Label.new()
	val_label.text = "%.2f" % default
	val_label.custom_minimum_size = Vector2(50.0, 0.0)
	val_label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(val_label)

	slider.value_changed.connect(func(val: float):
		val_label.text = "%.2f" % val
		param_changed.emit(id, val)
	)


func _add_bg(label: Label) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	bg.corner_radius_top_left = 6
	bg.corner_radius_top_right = 6
	bg.corner_radius_bottom_left = 6
	bg.corner_radius_bottom_right = 6
	bg.content_margin_left = 8
	bg.content_margin_right = 8
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	label.add_theme_stylebox_override("normal", bg)


func _toggle_pause() -> void:
	_paused = not _paused
	if wave_spawner != null:
		wave_spawner.set_process(not _paused)
	get_tree().paused = _paused
