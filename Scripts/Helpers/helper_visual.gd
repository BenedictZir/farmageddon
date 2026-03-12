class_name HelperVisual
extends Node2D


enum AnimState {
	IDLE,
	WALK,
	CARRY,
	DOING,
	DIG,
	RUN,
	DEATH,
	HURT,
	ATTACK,
}

const ANIM_NAMES := {
	AnimState.IDLE: "idle",
	AnimState.WALK: "walk",
	AnimState.CARRY: "carry",
	AnimState.DOING: "doing",
	AnimState.DIG: "dig",
	AnimState.RUN: "run",
	AnimState.DEATH: "death",
	AnimState.HURT: "hurt",
	AnimState.ATTACK: "attack",
}

@onready var base: AnimatedSprite2D = $Base
@onready var hair: AnimatedSprite2D = $Hair
@onready var tool_sprite: AnimatedSprite2D = $Tool

var _sprites: Array[AnimatedSprite2D]
var _current_state := AnimState.IDLE
var _facing_direction := Vector2.DOWN
var _locked := false

signal animation_state_finished(state: AnimState)


func _ready() -> void:
	_sprites = [base, hair, tool_sprite]
	base.animation_finished.connect(_on_base_animation_finished)
	play_state(AnimState.IDLE)


func get_current_state() -> AnimState:
	return _current_state


func is_locked() -> bool:
	return _locked


func update_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing_direction = direction
		_update_flip()


func play_state(new_state: AnimState) -> void:
	if _locked and new_state != AnimState.DEATH:
		return
	_current_state = new_state
	_locked = _is_oneshot_state(new_state)
	var anim_name: String = ANIM_NAMES[new_state]
	_play_on_all(anim_name)
	_update_flip()
	_update_tool_visibility()


func play_idle() -> void: play_state(AnimState.IDLE)
func play_walk() -> void: play_state(AnimState.WALK)
func play_doing() -> void: play_state(AnimState.DOING)
func play_dig() -> void: play_state(AnimState.DIG)
func play_attack() -> void: play_state(AnimState.ATTACK)
func play_hurt() -> void: play_state(AnimState.HURT)
func play_death() -> void: play_state(AnimState.DEATH)


func update_movement_anim(direction: Vector2) -> void:
	if _locked:
		return
	update_direction(direction)
	if direction == Vector2.ZERO:
		if _current_state != AnimState.IDLE:
			play_state(AnimState.IDLE)
	else:
		if _current_state != AnimState.WALK:
			play_state(AnimState.WALK)


func _play_on_all(anim_name: String) -> void:
	for sprite in _sprites:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name)
		else:
			sprite.stop()


func _update_flip() -> void:
	if _facing_direction.x != 0:
		var flip := _facing_direction.x < 0
		for sprite in _sprites:
			sprite.flip_h = flip


func _update_tool_visibility() -> void:
	match _current_state:
		AnimState.DOING, AnimState.DIG, AnimState.ATTACK:
			tool_sprite.visible = true
		_:
			tool_sprite.visible = false


func _is_oneshot_state(state: AnimState) -> bool:
	return state in [AnimState.DOING, AnimState.DIG, AnimState.HURT, AnimState.DEATH, AnimState.ATTACK]


func _on_base_animation_finished() -> void:
	if not _locked:
		return
	var finished_state := _current_state
	_locked = false
	animation_state_finished.emit(finished_state)
	if finished_state != AnimState.DEATH:
		play_state(AnimState.IDLE)
