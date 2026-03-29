extends State

## WarriorAttack: Play attack animation and deal damage at the end.

func enter() -> void:
	super()
	entity.movement_component.move(entity, Vector2.ZERO)
	
	if entity._is_enemy_attackable(entity._target_enemy):
		entity.helper_visual.update_direction(entity._target_enemy.global_position - entity.global_position)
		entity.helper_visual.play_attack()
	else:
		transition.emit("roam")

func physics_update(_delta: float) -> void:
	# The state stays here while locked.
	# helper.gd captures animation_state_finished and routes it to the FSM.
	pass

func on_animation_finished(anim_state) -> void:
	if anim_state == HelperVisual.AnimState.ATTACK:
		if entity._is_enemy_attackable(entity._target_enemy):
			if entity._target_enemy.has_node("Components/HealthComponent"):
				var dist := entity.global_position.distance_to(entity._target_enemy.global_position)
				if dist <= entity.attack_range * 1.5:
					entity._target_enemy.get_node("Components/HealthComponent").take_damage(entity.attack_damage)
		
		# Transition to chase so we stick onto the target instead of wandering off
		transition.emit("chase")
