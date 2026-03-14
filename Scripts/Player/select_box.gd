extends Node2D

@export var item_size := Vector2i(1, 1)

const TILE_SIZE := 16
const REST_INSET := 2.0
const PULSE_AMOUNT := 2.0
const PULSE_STEP := 0.1
const SCAN_RADIUS := 16.0  # 1 tiles

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
var _directions: Array[Vector2]
var _error_tween: Tween
var _is_placing := false
var _is_error := false

## Currently targeted interactable node (PlantableTile, etc.)
var current_target: Node2D = null

signal placing_finished


func _ready() -> void:
	_corners = [bottom_left, bottom_right, top_right, top_left]
	_anim_players = [_anim_bl, _anim_br, _anim_tr, _anim_tl]
	_directions = [
		Vector2(-1, 1),
		Vector2(1, 1),
		Vector2(1, -1),
		Vector2(-1, -1),
	]
	_anim_bl.animation_finished.connect(_on_animation_finished)

	# Position independently from parent (stays at world pos during placing)
	top_level = true
	_rebuild_animations()
	visible = false


func _physics_process(_delta: float) -> void:
	var player := get_parent()
	if not player:
		return

	# Don't interrupt placing or error animation
	if _is_placing or _is_error:
		return

	# Only scan when player is carrying
	if not player.get("is_carrying"):
		if visible:
			hide_box()
			current_target = null
		return

	# Find best interactable nearby (ALL interactables, not just available)
	var best := _find_best_target(player)
	if best:
		current_target = best
		var target_world := best.global_position
		global_position = target_world
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

	# Get facing direction from player visual
	var facing_right := true
	var player_visual = player.get("player_visual")
	if player_visual and player_visual.get("base"):
		facing_right = not player_visual.base.flip_h

	var facing_dir := Vector2.RIGHT if facing_right else Vector2.LEFT

	# Score each target: prefer ones in facing direction, then closest
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


func set_size(new_size: Vector2i) -> void:
	item_size = new_size
	_rebuild_animations()
	_play_all("RESET")


func play_selecting() -> void:
	visible = true
	_play_all("selecting")


func play_placing() -> void:
	_is_placing = true
	visible = true
	_play_all("placing")


func hide_box() -> void:
	_play_all("RESET")
	visible = false


func show_selecting() -> void:
	play_selecting()


func play_error() -> void:
	visible = true
	_is_error = true

	# Kill any running error tweeFn first
	if _error_tween and _error_tween.is_running():
		_error_tween.kill()

	# Always snap back to target position first to prevent drift
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


func _rebuild_animations() -> void:
	var half_w := (item_size.x * TILE_SIZE) / 2.0 - 1.0
	var half_h := (item_size.y * TILE_SIZE) / 2.0 - 1.0

	var edge_positions: Array[Vector2] = [
		Vector2(-half_w, half_h),   # BL
		Vector2(half_w, half_h),    # BR
		Vector2(half_w, -half_h),   # TR
		Vector2(-half_w, -half_h),  # TL
	]

	for i in range(4):
		var ap := _anim_players[i]
		var lib: AnimationLibrary = ap.get_animation_library(&"")
		var edge := edge_positions[i]
		var dir := _directions[i]
		var rest := edge + dir * (-REST_INSET)

		# --- RESET ---
		var reset_anim := Animation.new()
		reset_anim.length = 0.001
		var t0 := reset_anim.add_track(Animation.TYPE_VALUE)
		reset_anim.track_set_path(t0, ".:position")
		reset_anim.track_insert_key(t0, 0.0, rest)
		var t1 := reset_anim.add_track(Animation.TYPE_VALUE)
		reset_anim.track_set_path(t1, ".:modulate")
		reset_anim.track_insert_key(t1, 0.0, Color(1, 1, 1, 1))
		lib.remove_animation(&"RESET")
		lib.add_animation(&"RESET", reset_anim)

		# --- SELECTING ---
		var sel := Animation.new()
		sel.length = 0.4
		sel.loop_mode = Animation.LOOP_PINGPONG
		var st := sel.add_track(Animation.TYPE_VALUE)
		sel.track_set_path(st, ".:position")
		sel.value_track_set_update_mode(st, Animation.UPDATE_DISCRETE)
		sel.track_insert_key(st, 0.0, edge)
		sel.track_insert_key(st, 0.1, edge + dir * 1.0)
		sel.track_insert_key(st, 0.2, edge + dir * PULSE_AMOUNT)
		sel.track_insert_key(st, 0.3, edge + dir * 1.0)
		sel.track_insert_key(st, 0.4, edge)
		lib.remove_animation(&"selecting")
		lib.add_animation(&"selecting", sel)

		# --- PLACING ---
		var plc := Animation.new()
		plc.length = 0.3
		var pt := plc.add_track(Animation.TYPE_VALUE)
		plc.track_set_path(pt, ".:position")
		plc.track_insert_key(pt, 0.0, edge)
		plc.track_insert_key(pt, 0.1, edge)
		plc.track_insert_key(pt, 0.3, Vector2.ZERO)
		var mt := plc.add_track(Animation.TYPE_VALUE)
		plc.track_set_path(mt, ".:modulate")
		plc.value_track_set_update_mode(mt, Animation.UPDATE_DISCRETE)
		plc.track_insert_key(mt, 0.0, Color(4, 4, 4, 1))
		plc.track_insert_key(mt, 0.05, Color(6, 6, 6, 1))
		plc.track_insert_key(mt, 0.1, Color(1, 1, 1, 1))
		plc.track_insert_key(mt, 0.2, Color(1, 1, 1, 0.5))
		plc.track_insert_key(mt, 0.3, Color(1, 1, 1, 0))
		lib.remove_animation(&"placing")
		lib.add_animation(&"placing", plc)
