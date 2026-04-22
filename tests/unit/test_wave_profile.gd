extends RefCounted

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	seed(1234)
	var large_profile = WaveProfileScript.large()
	if large_profile.damage_risk <= 0.0:
		failures.append("large wave profile should have positive damage risk")
	if large_profile.drift_speed < 2.0 or large_profile.drift_speed > 5.0:
		failures.append("large profile drift_speed should be between 2.0 and 5.0, got %f" % large_profile.drift_speed)

	var small_profile = WaveProfileScript.small()
	if is_equal_approx(small_profile.turn_push, 0.0):
		failures.append("small wave profile should apply turn push")
	if small_profile.drift_speed < 1.0 or small_profile.drift_speed > 3.0:
		failures.append("small profile drift_speed should be between 1.0 and 3.0, got %f" % small_profile.drift_speed)

	return failures
