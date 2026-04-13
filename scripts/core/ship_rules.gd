class_name ShipRules
extends RefCounted

static func apply_wave(model, profile, airborne_factor: float) -> float:
	if model == null:
		return 0.0

	if not profile.is_large:
		return 0.0

	var scaled_factor: float = max(1.0, airborne_factor)
	var damage_amount: float = profile.damage_risk * scaled_factor
	return model.add_damage(damage_amount)
