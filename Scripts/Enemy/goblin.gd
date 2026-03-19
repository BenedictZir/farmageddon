extends EnemyBase
class_name Goblin

## Goblin enemy core controller. Uses FSM for state management.

@onready var loot: GoblinLoot = $Loot


@export var steal_detect_range := 120.0
@export var steal_duration := 3.0
@onready var held_item_sprite: Sprite2D = $HeldItemSprite

var target_tile: Node2D = null
var flee_target := Vector2.ZERO

func show_held_item(icon: Texture2D) -> void:
	if held_item_sprite:
		held_item_sprite.texture = icon
		held_item_sprite.visible = true


func hide_held_item() -> void:
	if held_item_sprite:
		held_item_sprite.visible = false
		held_item_sprite.texture = null

func update_flip(dir: Vector2) -> void:
	super(dir)
	if held_item_sprite and dir.x != 0:
		held_item_sprite.flip_h = dir.x < 0

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
	var extents := GameManager.map_extents
	var edges := [
		Vector2(pos.x, -extents.y),
		Vector2(pos.x, extents.y),
		Vector2(-extents.x, pos.y),
		Vector2(extents.x, pos.y),
	]
	var nearest = edges[0]
	var nearest_dist := pos.distance_to(edges[0])
	for e in edges:
		var d := pos.distance_to(e)
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	return nearest


func _on_screen_exited() -> void:
	if fsm.current_state and fsm.current_state.name.to_lower() == "flee":
		queue_free()
