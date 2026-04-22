class_name WaveProfile
extends RefCounted

var turn_push: float = 0.0
var lift_force: float = 0.0
var damage_risk: float = 0.0
var drift_speed: float = 0.0
var is_large: bool = false


static func small(push_direction: float = 0.45):
	var profile = load("res://scripts/waves/wave_profile.gd").new()
	profile.turn_push = push_direction
	profile.lift_force = 0.0
	profile.damage_risk = 0.0
	profile.is_large = false
	profile.drift_speed = randf_range(1.0, 3.0)
	return profile


static func large(push_direction: float = 0.9):
	var profile = load("res://scripts/waves/wave_profile.gd").new()
	profile.turn_push = push_direction
	profile.lift_force = 6.0
	profile.damage_risk = 8.0
	profile.is_large = true
	profile.drift_speed = randf_range(2.0, 5.0)
	return profile
