extends RefCounted

const DebugOverlayScript = preload("res://scripts/debug/debug_overlay.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	var overlay = DebugOverlayScript.new()

	if not overlay.wave_zones_visible:
		failures.append("wave zones should be visible by default in debug overlay")

	if not overlay.stats_panel_visible:
		failures.append("stats panel should be visible by default in debug overlay")

	if not overlay.has_method("_toggle_wave_zones"):
		failures.append("debug overlay should expose wave zone toggle method")

	if not overlay.has_method("_toggle_stats_panel"):
		failures.append("debug overlay should expose stats panel toggle method")

	overlay.free()
	return failures
