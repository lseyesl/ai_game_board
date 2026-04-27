class_name ShipRules
extends RefCounted

# Damage is now computed directly in ShipController as
# wave.damage_per_second * delta. ShipRules is retained
# as a namespace for potential future rule validation.
