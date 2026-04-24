extends RefCounted

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	seed(1234)
	var large_profile = WaveProfileScript.large()
	if large_profile.damage_risk <= 0.0:
		failures.append("large wave profile should have positive damage risk")
	if large_profile.drift_speed < 0.3 or large_profile.drift_speed > 1.2:
		failures.append("large profile drift_speed should be between 0.3 and 1.2, got %f" % large_profile.drift_speed)

	var small_profile = WaveProfileScript.small()
	if is_equal_approx(small_profile.turn_push, 0.0):
		failures.append("small wave profile should apply turn push")
	if small_profile.drift_speed < 0.2 or small_profile.drift_speed > 0.8:
		failures.append("small profile drift_speed should be between 0.2 and 0.8, got %f" % small_profile.drift_speed)

	return failures
