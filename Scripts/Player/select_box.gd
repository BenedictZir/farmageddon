extends Node2D

@export var item_size := Vector2i(1, 1)

const SCAN_RADIUS := 16.0  # 1 tile

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

var current_target: Node2D = null

signal placing_finished


func _ready() -> void:
	_corners = [bottom_left, bottom_right, top_right, top_left]
	_anim_players = [_anim_bl, _anim_br, _anim_tr, _anim_tl]
	_anim_bl.animation_finished.connect(_on_animation_finished)
	top_level = true
	SelectBoxAnimations.build(_anim_players, item_size)


func _physics_process(_delta: float) -> void:
	var player := get_parent()
	if not player:
		return

	if _is_placing or _is_error:
		return

	var is_carrying: bool = player.get("is_carrying")
	var is_holding_harvest: bool = player.get("_is_holding_harvest")
	var best := _find_best_target(player)

	if is_carrying:
		if is_holding_harvest:
			# Harvest in hand → snap to player (sell)
			# Future: snap to feedable animal if nearby
			current_target = player
			global_position = player.global_position
			if not visible:
				play_selecting()
		elif best:
			var held_item = player.get("_held_item")
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


func _find_best_target(player: Node2D) -> Node2D:
	var space := player.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = SCAN_RADIUS
	query.shape = shape
	query.transform = Transform2D(0, player.global_position)
	query.collision_mask = 8  # layer 4 = Interactable
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := space.intersect_shape(query, 16)
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
		var collider: Node2D = result.collider
		var to_target := collider.global_position - player.global_position
		var dist := to_target.length()
		if dist < 0.01:
			dist = 0.01
		var facing_bonus := to_target.normalized().dot(facing_dir)
		var score := facing_bonus * 10.0 - dist
		if score > best_score:
			best_score = score
			best_node = collider

	return best_node


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
