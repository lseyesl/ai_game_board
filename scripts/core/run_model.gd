class_name RunModel
extends RefCounted

static var session_best_distance: float = 0.0

var damage: float = 0.0
var distance: float = 0.0
var invulnerable: bool = false
var repairing: bool = false


func add_damage(amount: float) -> float:
	if amount <= 0.0 or invulnerable or is_game_over():
		return 0.0
	var previous_damage := damage
	damage = min(100.0, damage + amount)
	return damage - previous_damage


func repair(amount: float) -> void:
	if amount <= 0.0 or is_game_over():
		return
	damage = max(0.0, damage - amount)


func advance_distance(amount: float) -> void:
	if amount <= 0.0 or is_game_over():
		return
	distance += amount
	session_best_distance = max(session_best_distance, distance)


func is_game_over() -> bool:
	return damage >= 100.0


func get_best_distance() -> float:
	return session_best_distance
