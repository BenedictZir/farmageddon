extends EnemyBase
class_name GoblinAI

## Goblin enemy core controller. Uses FSM for state management.

@onready var loot: GoblinLoot = $Loot
@onready var fsm: FiniteStateMachine = $StateMachine

@export var player_detect_range := 80.0
@export var steal_detect_range := 120.0
@export var attack_range := 16.0
@export var attack_stop_range := 20.0
@export var steal_duration := 3.0
@export var run_speed := 45.0
@export var walk_speed := 25.0
@export var roam_change_interval := 2.0

var target_tile: Node2D = null
var flee_target := Vector2.ZERO
var attack_cooldown := 0.0


func _ready() -> void:
	super()
	movement_component.movement_speed = run_speed
	visual.anim_finished.connect(_on_visual_anim_finished)
	fsm.init(self)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	attack_cooldown -= delta
	fsm.process_physics(delta)

func _process(delta: float) -> void:
	if is_dead:
		return
	fsm.process_frame(delta)


func do_attack() -> void:
	attack_cooldown = 1.5
	visual.play_anim_locked("attack")
	attack_component.activate(visual.flip_h)


func _on_death() -> void:
	is_dead = true
	velocity = Vector2.ZERO

	if loot.has_loot():
		_drop_loot()
		held_item_sprite.hide()

	visual.play_anim_locked("death")


func _drop_loot() -> void:
	var drop_data := loot.get_drop_data()
	var dropped_scene := preload("res://Scenes/Items/dropped_item.tscn")
	var item := dropped_scene.instantiate()
	get_parent().call_deferred("add_child", item)
	item.set_deferred("global_position", global_position)
	item.call_deferred("setup", drop_data)


func find_nearest_stealable() -> Node2D:
	var tiles := get_tree().get_nodes_in_group("plantable_tiles")
	var best: Node2D = null
	var best_dist := INF

	for tile in tiles:
		if not is_tile_stealable(tile):
			continue
		var dist := global_position.distance_to(tile.global_position)
		if dist < steal_detect_range and dist < best_dist:
			best_dist = dist
			best = tile

	return best


func is_tile_stealable(tile: Node2D) -> bool:
	return tile and tile.get("occupied") and tile.get("placed_crop") != null


func get_nearest_edge() -> Vector2:
	var pos := global_position
	# For a map centered at (0,0) with 640x360 boundaries:
	var edges := [
		Vector2(pos.x, -105),
		Vector2(pos.x, 105),
		Vector2(-170, pos.y),
		Vector2(170, pos.y),
	]
	var nearest = edges[0]
	var nearest_dist := pos.distance_to(edges[0])
	for e in edges:
		var d := pos.distance_to(e)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


func _on_visual_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		attack_component.deactivate()
	elif anim_name == "death":
		queue_free()

func _on_screen_exited() -> void:
	if fsm.current_state and fsm.current_state.name.to_lower() == "flee":
		queue_free()
