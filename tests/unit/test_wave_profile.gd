extends RefCounted

const WaveProfileScript = preload("res://scripts/waves/wave_profile.gd")


func run() -> Array[String]:
	var failures: Array[String] = []
	var large_profile = WaveProfileScript.large()
	if large_profile.damage_risk <= 0.0:
		failures.append("large wave profile should have positive damage risk")

	var small_profile = WaveProfileScript.small()
	if is_equal_approx(small_profile.turn_push, 0.0):
		failures.append("small wave profile should apply turn push")

	return failures
