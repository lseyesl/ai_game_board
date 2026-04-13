class_name HUD
extends CanvasLayer

var run_model = null
var title_label: Label
var distance_label: Label
var best_distance_label: Label
var damage_bar: ProgressBar
var damage_label: Label
var safe_label: Label
var game_over_panel: PanelContainer
var game_over_label: Label


func _ready() -> void:
	_build_ui()


func _process(_delta: float) -> void:
	if run_model == null:
		return

	distance_label.text = "Distance %.0fm" % run_model.distance
	best_distance_label.text = "Best %.0fm" % run_model.get_best_distance()
	damage_bar.value = run_model.damage
	damage_label.text = "Hull %d%%" % int(round(run_model.damage))
	safe_label.text = "Repairing / Invulnerable" if run_model.invulnerable else "Open Water"
	safe_label.modulate = Color("#D9ED92") if run_model.invulnerable else Color.WHITE
	game_over_panel.visible = run_model.is_game_over()
	if run_model.is_game_over():
		game_over_label.text = "Run Over\nDistance %.0fm\nPress Enter / Tap to restart" % run_model.distance


func set_run_model(model) -> void:
	run_model = model


func flash_damage() -> void:
	if damage_label == null:
		return
	damage_label.modulate = Color("#FF6B6B")
	var tween := create_tween()
	tween.tween_property(damage_label, "modulate", Color.WHITE, 0.35)


func _build_ui() -> void:
	if title_label != null:
		return

	var margin := MarginContainer.new()
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	title_label = Label.new()
	title_label.text = "Boat Survival"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	root.add_child(title_label)

	distance_label = Label.new()
	distance_label.text = "Distance 0m"
	distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	distance_label.add_theme_font_size_override("font_size", 28)
	root.add_child(distance_label)

	best_distance_label = Label.new()
	best_distance_label.text = "Best 0m"
	best_distance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best_distance_label.add_theme_font_size_override("font_size", 20)
	root.add_child(best_distance_label)

	damage_bar = ProgressBar.new()
	damage_bar.max_value = 100.0
	damage_bar.show_percentage = false
	damage_bar.custom_minimum_size = Vector2(0.0, 26.0)
	root.add_child(damage_bar)

	damage_label = Label.new()
	damage_label.text = "Hull 0%"
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", 22)
	root.add_child(damage_label)

	safe_label = Label.new()
	safe_label.text = "Open Water"
	safe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	safe_label.add_theme_font_size_override("font_size", 22)
	root.add_child(safe_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	game_over_panel = PanelContainer.new()
	game_over_panel.visible = false
	game_over_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(game_over_panel)

	game_over_label = Label.new()
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 28)
	game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game_over_panel.add_child(game_over_label)
