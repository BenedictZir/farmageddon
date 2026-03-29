class_name WarriorHelper
extends Helper

## Warrior NPC variables used by its FSM states

var _target_enemy: Node2D = null
var _home_position: Vector2

## How often to scan for enemies
@export var scan_interval := 0.5
## How close to be before attacking
@export var attack_range := 16.0
## Damage dealt per attack
@export var attack_damage := 25.0

func _ready() -> void:
	super._ready()
	_home_position = Vector2.ZERO  # Will be updated when entering roam
	add_to_group("helpers")

func _find_enemy() -> bool:
	# First try the group — if enemies register themselves there
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	
	# Fallback: recursively scan the scene for all EnemyBase instances
	if enemies.is_empty():
		enemies = []
		_collect_enemies(get_tree().current_scene, enemies)
	
	if enemies.is_empty():
		return false

	var nearest: Node2D = null
	var nearest_dist := INF
	for enemy in enemies:
		if not _is_enemy_attackable(enemy):
			continue
		if enemy is Node2D:
			var dist := global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest = enemy
				nearest_dist = dist

	if nearest:
		_target_enemy = nearest
		return true
	return false


func _is_enemy_attackable(enemy: Node2D) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is EnemyBase and enemy.is_dead:
		return false
	# Bird is only hittable when it has landed to eat.
	if enemy is Bird and not enemy.is_eating:
		return false
	return true

func _collect_enemies(node: Node, result: Array) -> void:
	if node is EnemyBase:
		result.append(node)
	for child in node.get_children():
		_collect_enemies(child, result)
