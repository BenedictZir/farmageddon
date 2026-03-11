extends Node2D

@export var item_size := Vector2i(1, 1)

const TILE_SIZE := 16
const REST_INSET := 2.0
const PULSE_AMOUNT := 2.0
const PULSE_STEP := 0.1

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
	
	if item_size != Vector2i(1, 1):
		_rebuild_animations()


func set_size(new_size: Vector2i) -> void:
	item_size = new_size
	_rebuild_animations()
	_play_all("RESET")


func play_selecting() -> void:
	visible = true
	_play_all("selecting")


func play_placing() -> void:
	visible = true
	_play_all("placing")


func hide_box() -> void:
	_play_all("RESET")
	visible = false


func show_selecting() -> void:
	play_selecting()


func _play_all(anim_name: String) -> void:
	for ap in _anim_players:
		ap.play(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == &"placing":
		visible = false
		_play_all("RESET")
		placing_finished.emit()


func _rebuild_animations() -> void:
	var half_w := (item_size.x * TILE_SIZE) / 2.0
	var half_h := (item_size.y * TILE_SIZE) / 2.0
	
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
		# Position: hold at edge during flash, then smooth shrink to center
		var pt := plc.add_track(Animation.TYPE_VALUE)
		plc.track_set_path(pt, ".:position")
		plc.track_insert_key(pt, 0.0, edge)
		plc.track_insert_key(pt, 0.1, edge)
		plc.track_insert_key(pt, 0.3, Vector2.ZERO)
		# Modulate: flash white then fade (discrete)
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
