extends Node2D

@export var item_size := Vector2i(1, 1)

const SCAN_RADIUS := 16.0  # 1 tile
const SCAN_RESULT_LIMIT := 16

@onready var bottom_left: Sprite2D = $BottomLeft
@onready var bottom_right: Sprite2D = $BottomRight
@onready var top_right: Sprite2D = $TopRight
@onready var top_left: Sprite2D = $TopLeft

@onready var _anim_bl: AnimationPlayer = $BottomLeft/AnimationPlayer
@onready var _anim_br: AnimationPlayer = $BottomRight/AnimationPlayer
@onready var _anim_tr: AnimationPlayer = $TopRight/AnimationPlayer
@onready var _anim_tl: AnimationPlayer = $TopLeft/AnimationPlayer

var _corners: Array[Sprite2D]
var _anim_players: Array[AnimationPlayer]
var _error_tween: Tween
var _is_placing := false
var _is_error := false
var _scan_timer := 0.0
var _cached_best_target: Node2D
var _scan_query := PhysicsShapeQueryParameters2D.new()
var _scan_shape := CircleShape2D.new()

@export var scan_interval := 0.08

var current_target: Node2D = null

signal placing_finished


func _ready() -> void:
	_corners = [bottom_left, bottom_right, top_right, top_left]
	_anim_players = [_anim_bl, _anim_br, _anim_tr, _anim_tl]
	_anim_bl.animation_finished.connect(_on_animation_finished)
	top_level = true
	SelectBoxAnimations.build(_anim_players, item_size)
	_scan_shape.radius = SCAN_RADIUS
	_scan_query.shape = _scan_shape
	_scan_query.collision_mask = 8 # layer 4 = Interactable
	_scan_query.collide_with_areas = true
	_scan_query.collide_with_bodies = false


func _physics_process(_delta: float) -> void:
	var player := get_parent()
	if not player:
		return

	if _is_placing or _is_error:
		return

	var inventory := player.get("inventory") as PlayerInventory
	var is_carrying := inventory.is_carrying if inventory else bool(player.get("is_carrying"))
	var is_holding_product := inventory.is_holding_product() if inventory else bool(player.get("_is_holding_product"))
	var held_item: ItemData = inventory.get_held_item() if inventory else player.get("_held_item")

	_scan_timer -= _delta
	if _scan_timer <= 0.0:
		_scan_timer = maxf(0.01, scan_interval)
		_cached_best_target = _find_best_target(player, is_carrying, is_holding_product, held_item)
	elif _cached_best_target and not is_instance_valid(_cached_best_target):
		_cached_best_target = null

	var best := _cached_best_target

	if is_carrying:
		if is_holding_product:
			# Product in hand → check for feedable animal first
			if best and best.has_method("is_feedable") and best.is_feedable() and held_item and held_item.has_method("is_animal_feed") and held_item.is_animal_feed():
				current_target = best
				global_position = best.global_position
				if not visible:
					play_selecting()
			else:
				# No feedable animal nearby → snap to player (sell)
				current_target = player
				global_position = player.global_position
				if not visible:
					play_selecting()
		elif best:
			if held_item and held_item is ItemData \
				and best.has_method("accepts_type") \
				and held_item.get_placeable_type() >= 0 \
				and best.accepts_type(held_item.get_placeable_type()):
				current_target = best
				global_position = best.global_position
				if not visible:
					play_selecting()
			else:
				current_target = null
				if visible:
					hide_box()
		else:
			current_target = null
			if visible:
				hide_box()
	else:
		if best and best.has_method("is_harvestable") and best.is_harvestable():
			current_target = best
			global_position = best.global_position
			if not visible:
				play_selecting()
		else:
			current_target = null
			if visible:
				hide_box()


func _find_best_target(player: Node2D, is_carrying: bool, is_holding_product: bool, held_item: ItemData) -> Node2D:
	var space := player.get_world_2d().direct_space_state
	_scan_query.transform = Transform2D(0, player.global_position)

	var results := space.intersect_shape(_scan_query, SCAN_RESULT_LIMIT)
	if results.is_empty():
		return null

	var facing_right := true
	var player_visual = player.get("player_visual")
	if player_visual and player_visual.get("base"):
		facing_right = not player_visual.base.flip_h

	var facing_dir := Vector2.RIGHT if facing_right else Vector2.LEFT
	var best_node: Node2D = null
	var best_score := -INF

	for result in results:
		var collider: Node2D = result.collider as Node2D
		if not collider:
			continue
		var to_target := collider.global_position - player.global_position
		var dist := to_target.length()
		if dist < 0.01:
			dist = 0.01
		var facing_bonus := to_target.normalized().dot(facing_dir)
		var context_bonus := _get_context_priority_bonus(collider, is_carrying, is_holding_product, held_item)
		var score := context_bonus + (facing_bonus * 10.0) - dist
		if score > best_score:
			best_score = score
			best_node = collider

	return best_node


func _get_context_priority_bonus(collider: Node2D, is_carrying: bool, is_holding_product: bool, held_item: ItemData) -> float:
	if collider.has_method("pick_up"):
		return 30.0 if not is_carrying else -8.0

	if not is_carrying:
		if collider.has_method("is_harvestable") and collider.is_harvestable():
			return 6.0
		return -4.0

	if is_holding_product:
		var can_feed = held_item \
			and held_item.has_method("is_animal_feed") \
			and held_item.is_animal_feed() \
			and collider.has_method("is_feedable") \
			and collider.is_feedable()
		return 8.0 if can_feed else -4.0

	if held_item \
		and collider.has_method("accepts_type") \
		and held_item.get_placeable_type() >= 0 \
		and collider.accepts_type(held_item.get_placeable_type()):
		return 8.0

	return -6.0


# ── Animation API ────────────────────────────────────────

func set_size(new_size: Vector2i) -> void:
	item_size = new_size
	SelectBoxAnimations.build(_anim_players, item_size)
	_is_placing = false
	_is_error = false
	if _error_tween and _error_tween.is_running():
		_error_tween.kill()
		for c in _corners: c.modulate = Color.WHITE
	_play_all("RESET")
	visible = false


func play_selecting() -> void:
	_is_placing = false
	visible = true
	_play_all("selecting")


func play_placing() -> void:
	_is_placing = true
	visible = true
	_play_all("placing")


func hide_box() -> void:
	_is_placing = false
	_play_all("RESET")
	visible = false


func show_selecting() -> void:
	play_selecting()


func play_error() -> void:
	visible = true
	_is_error = true

	if _error_tween and _error_tween.is_running():
		_error_tween.kill()

	if current_target:
		global_position = current_target.global_position

	for corner in _corners:
		corner.modulate = Color(1, 0.2, 0.2, 1)

	var base_pos := global_position
	_error_tween = create_tween()
	_error_tween.tween_property(self, "global_position", base_pos + Vector2(2, 0), 0.05)
	_error_tween.tween_property(self, "global_position", base_pos + Vector2(-2, 0), 0.05)
	_error_tween.tween_property(self, "global_position", base_pos + Vector2(2, 0), 0.05)
	_error_tween.tween_property(self, "global_position", base_pos + Vector2(-2, 0), 0.05)
	_error_tween.tween_property(self, "global_position", base_pos + Vector2(1, 0), 0.05)
	_error_tween.tween_property(self, "global_position", base_pos, 0.05)
	_error_tween.tween_callback(func():
		_is_error = false
		for c in _corners:
			c.modulate = Color.WHITE
		play_selecting()
	)


func _play_all(anim_name: String) -> void:
	for ap in _anim_players:
		ap.play(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"placing":
		_is_placing = false
		visible = false
		_play_all("RESET")
		placing_finished.emit()
