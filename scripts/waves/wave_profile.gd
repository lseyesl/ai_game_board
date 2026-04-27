class_name WaveProfile
extends RefCounted

var turn_push: float = 0.0
var lateral_force: float = 0.0
var speed_multiplier: float = 1.0
var damage_per_second: float = 0.0
var drift_speed: float = 0.0
var is_large: bool = false


static func small(push_direction: float = 0.35) -> WaveProfile:
	var profile := WaveProfile.new()
	profile.turn_push = push_direction
	profile.lateral_force = 3.0
	profile.speed_multiplier = 0.85
	profile.damage_per_second = 0.0
	profile.is_large = false
	profile.drift_speed = randf_range(0.8, 2.0)
	return profile


static func large(push_direction: float = 0.7) -> WaveProfile:
	var profile := WaveProfile.new()
	profile.turn_push = push_direction
	profile.lateral_force = 7.0
	profile.speed_multiplier = 0.6
	profile.damage_per_second = 5.0
	profile.is_large = true
	profile.drift_speed = randf_range(1.0, 3.0)
	return profile
