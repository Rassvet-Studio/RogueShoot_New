class_name DamageReceiver
extends Area3D
## Hitbox adapter that forwards hitscan damage to its owning actor.

func apply_damage(amount: float, source = null) -> bool:
	var owner_actor := get_parent()
	if owner_actor != null and owner_actor.has_method("apply_damage"):
		return owner_actor.apply_damage(amount, source)
	return false
