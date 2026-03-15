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
	ROLL,
}

## Whether the current carry uses the no-tool variant
var _carry_no_tool := false

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
	AnimState.ROLL: "roll",
}

@onready var base: AnimatedSprite2D = $Base
@onready var hair: AnimatedSprite2D = $Hair
@onready var tool_sprite: AnimatedSprite2D = $Tool
@onready var held_item_sprite: Sprite2D = $HeldItemSprite

@onready var interact_bar: TextureProgressBar = $"../InteractBar"

var _sprites: Array[AnimatedSprite2D]
var _current_state := AnimState.IDLE
var _facing_direction := Vector2.DOWN
var _locked := false

signal animation_state_finished(state: AnimState)


func _ready() -> void:
	_sprites = [base, hair, tool_sprite]
	base.animation_finished.connect(_on_base_animation_finished)
	play_state(AnimState.IDLE)
	hide_held_item()
	if interact_bar:
		interact_bar.visible = false


func _process(_delta: float) -> void:
	if interact_bar:
		if _locked and _current_state in [AnimState.DOING, AnimState.DIG]:
			interact_bar.visible = true
			var anim_name = ANIM_NAMES[_current_state]
			if base.sprite_frames and base.sprite_frames.has_animation(anim_name):
				var total_frames = float(base.sprite_frames.get_frame_count(anim_name))
				var current_progress = (float(base.frame) + base.frame_progress) / max(1.0, total_frames)
				interact_bar.value = current_progress * 100.0
		else:
			interact_bar.visible = false


func get_current_state() -> AnimState:
	return _current_state


func is_locked() -> bool:
	return _locked


func update_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		_facing_direction = direction
		_update_flip()


func set_carry_no_tool(enabled: bool) -> void:
	_carry_no_tool = enabled


func show_held_item(icon: Texture2D) -> void:
	held_item_sprite.texture = icon
	held_item_sprite.visible = true


func hide_held_item() -> void:
	held_item_sprite.visible = false
	held_item_sprite.texture = null


func play_state(new_state: AnimState) -> void:
	if _locked and new_state != AnimState.DEATH:
		return
	
	_current_state = new_state
	_locked = _is_oneshot_state(new_state)
	
	var anim_name: String = ANIM_NAMES[new_state]
	
	# For carry state: use carry_no_tool on tool sprite if flagged
	if new_state == AnimState.CARRY and _carry_no_tool:
		# Play carry on base/hair, carry_no_tool on tool
		for sprite in _sprites:
			if sprite == tool_sprite:
				if sprite.sprite_frames and sprite.sprite_frames.has_animation("carry_no_tool"):
					sprite.play("carry_no_tool")
				else:
					sprite.stop()
			else:
				if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
					sprite.play(anim_name)
				else:
					sprite.stop()
	else:
		_play_on_all(anim_name)
	
	_update_flip()


func play_idle() -> void:
	play_state(AnimState.IDLE)

func play_walk() -> void:
	play_state(AnimState.WALK)

func play_carry() -> void:
	play_state(AnimState.CARRY)

func play_doing() -> void:
	play_state(AnimState.DOING)

func play_dig() -> void:
	play_state(AnimState.DIG)

func play_run() -> void:
	play_state(AnimState.RUN)

func play_death() -> void:
	play_state(AnimState.DEATH)

func play_hurt() -> void:
	play_state(AnimState.HURT)

func play_attack() -> void:
	play_state(AnimState.ATTACK)

func play_roll() -> void:
	play_state(AnimState.ROLL)


func update_movement_anim(direction: Vector2, is_carrying: bool, is_running: bool) -> void:
	if _locked:
		return
	
	update_direction(direction)
	
	if direction == Vector2.ZERO:
		if is_carrying:
			if _current_state != AnimState.CARRY:
				play_state(AnimState.CARRY)
			# Standing still while carrying → freeze at frame 0
			for sprite in _sprites:
				if sprite.is_playing():
					sprite.stop()
					sprite.frame = 0
		else:
			if _current_state != AnimState.IDLE:
				play_state(AnimState.IDLE)
	else:
		if is_running:
			if _current_state != AnimState.RUN:
				play_state(AnimState.RUN)
		elif is_carrying:
			if _current_state != AnimState.CARRY:
				play_state(AnimState.CARRY)
			# Make sure animation is playing while moving
			for sprite in _sprites:
				if not sprite.is_playing():
					sprite.play()
		else:
			if _current_state != AnimState.WALK:
				play_state(AnimState.WALK)


func _play_on_all(anim_name: String) -> void:
	var speed_scale := 1.0
	
	if anim_name == "doing" or anim_name == "dig":
		# Speed up interaction animations based on UpgradeManager
		var bonus = UpgradeManager.interact_level * UpgradeManager.INTERACT_BONUS_PER_LEVEL
		speed_scale = 1.0 + bonus
		
	for sprite in _sprites:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name, speed_scale)
		else:
			sprite.stop()


func _update_flip() -> void:
	if _facing_direction.x != 0:
		var flip := _facing_direction.x < 0
		for sprite in _sprites:
			sprite.flip_h = flip
		# Flip held item sprite too
		if held_item_sprite:
			held_item_sprite.flip_h = flip


func _is_oneshot_state(state: AnimState) -> bool:
	return state in [AnimState.DOING, AnimState.DIG, AnimState.HURT, AnimState.DEATH, AnimState.ATTACK, AnimState.ROLL]


func _on_base_animation_finished() -> void:
	if not _locked:
		return
	
	var finished_state := _current_state
	_locked = false
	animation_state_finished.emit(finished_state)
	
	# Auto-return after one-shot anims (except death)
	if finished_state != AnimState.DEATH:
		var player := get_parent()
		if player and player.get("is_carrying"):
			play_state(AnimState.CARRY)
		else:
			play_state(AnimState.IDLE)
