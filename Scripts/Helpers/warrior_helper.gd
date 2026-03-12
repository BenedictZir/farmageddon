class_name WarriorHelper
extends Helper

## Warrior NPC — automatically seeks and attacks enemies.
## AI loop: Idle → find nearest enemy → walk to it → attack → repeat

enum WarriorState {
	IDLE_SCANNING,  # Looking for enemies
	CHASING,        # Moving toward an enemy
	ATTACKING,      # Playing attack animation
}

var warrior_state := WarriorState.IDLE_SCANNING
var _target_enemy: Node2D = null
var _scan_timer := 0.0

## How often to scan for enemies
@export var scan_interval := 0.5
## How close to be before attacking
@export var attack_range := 16.0
## Damage dealt per attack
@export var attack_damage := 25.0


func _ai_process(delta: float) -> void:
	match warrior_state:
		WarriorState.IDLE_SCANNING:
			_scan_timer += delta
			if _scan_timer >= scan_interval:
				_scan_timer = 0.0
				_find_enemy()
		WarriorState.CHASING:
			if not is_instance_valid(_target_enemy):
				# Target died or was removed
				warrior_state = WarriorState.IDLE_SCANNING
				_target_enemy = null
				has_target = false
				return
			# Update target position (enemy might move)
			target_position = _target_enemy.global_position
			# Check if close enough to attack
			var dist := global_position.distance_to(_target_enemy.global_position)
			if dist <= attack_range:
				has_target = false
				warrior_state = WarriorState.ATTACKING
				helper_visual.update_direction(_target_enemy.global_position - global_position)
				helper_visual.play_attack()
		WarriorState.ATTACKING:
			pass  # animation lock handles this


func _find_enemy() -> void:
	# Find nearest enemy in the "enemies" group
	var enemies := get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return

	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies:
		if enemy is Node2D:
			var dist := global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest = enemy
				nearest_dist = dist

	if nearest:
		_target_enemy = nearest
		warrior_state = WarriorState.CHASING
		move_to(nearest.global_position)


func _on_anim_finished(state: HelperVisual.AnimState) -> void:
	if state == HelperVisual.AnimState.ATTACK:
		# Deal damage to target if still valid and in range
		if is_instance_valid(_target_enemy) and _target_enemy.has_method("take_damage"):
			var dist := global_position.distance_to(_target_enemy.global_position)
			if dist <= attack_range * 1.5:
				_target_enemy.take_damage(attack_damage)
		# Go back to scanning
		warrior_state = WarriorState.IDLE_SCANNING
		_target_enemy = null
		_scan_timer = 0.0


func _on_arrived_at_target() -> void:
	if warrior_state == WarriorState.CHASING:
		# Should be close enough to attack now
		if is_instance_valid(_target_enemy):
			warrior_state = WarriorState.ATTACKING
			helper_visual.update_direction(_target_enemy.global_position - global_position)
			helper_visual.play_attack()
		else:
			warrior_state = WarriorState.IDLE_SCANNING
