extends RefCounted

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []

	# --- Small wave profile ---
	var small = WaveProfileScript.small()
	if small.is_large:
		failures.append("small profile is_large should be false")
	if small.turn_push <= 0.0:
		failures.append("small profile should have positive turn_push")
	if small.lateral_force <= 0.0:
		failures.append("small profile should have positive lateral_force")
	if small.speed_multiplier <= 0.0 or small.speed_multiplier > 1.0:
		failures.append("small profile speed_multiplier should be in (0,1], got %f" % small.speed_multiplier)
	if not is_equal_approx(small.damage_per_second, 0.0):
		failures.append("small profile damage_per_second should be 0, got %f" % small.damage_per_second)
	if small.drift_speed < 0.8 or small.drift_speed > 2.0:
		failures.append("small profile drift_speed should be between 0.8 and 2.0, got %f" % small.drift_speed)

	# --- Large wave profile ---
	var large = WaveProfileScript.large()
	if not large.is_large:
		failures.append("large profile is_large should be true")
	if large.turn_push <= 0.0:
		failures.append("large profile should have positive turn_push")
	if large.lateral_force <= small.lateral_force:
		failures.append("large profile lateral_force should exceed small")
	if large.speed_multiplier >= small.speed_multiplier:
		failures.append("large profile speed_multiplier should be lower (more slowdown) than small")
	if large.damage_per_second <= 0.0:
		failures.append("large profile should have positive damage_per_second")
	if large.drift_speed < 1.0 or large.drift_speed > 3.0:
		failures.append("large profile drift_speed should be between 1.0 and 3.0, got %f" % large.drift_speed)

	return failures
