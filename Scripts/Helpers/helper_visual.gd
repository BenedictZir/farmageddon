class_name HelperVisual
extends Node2D

enum AnimState {
	IDLE,
	WALK,
	CARRY,
	DOING,
	DIG,
	RUN,
	ATTACK,
	JUMP,
}

const ANIM_NAMES := {
	AnimState.IDLE: "idle",
	AnimState.WALK: "walk",
	AnimState.CARRY: "carry",
	AnimState.DOING: "doing",
	AnimState.DIG: "dig",
	AnimState.RUN: "run",
	AnimState.ATTACK: "attack",
	AnimState.JUMP: "jump",
}

const HAIR_STYLES = ["curlyhair", "longhair", "mophair", "shorthair", "spikeyhair"]
const ANIM_STRIPS = {
	"idle": "idle_strip9.png",
	"walk": "walk_strip8.png",
	"run": "run_strip8.png",
	"carry": "carry_strip8.png",
	"doing": "doing_strip8.png",
	"dig": "dig_strip13.png",
	"attack": "attack_strip10.png",
	"hurt": "hurt_strip8.png",
	"death": "death_strip13.png",
	"jump": "jump_strip9.png"
}

@onready var base: AnimatedSprite2D = $Base
@onready var hair: AnimatedSprite2D = $Hair
@onready var tool_sprite: AnimatedSprite2D = $Tool

var _sprites: Array[AnimatedSprite2D]
var _current_state := AnimState.IDLE
var _facing_direction := Vector2.DOWN
var _locked := false
var _is_carrying := false
var _carry_no_tool := false
var _held_sprite: Sprite2D = null
var _interact_bar: TextureProgressBar = null

signal animation_state_finished(state: AnimState)
signal jump_finished

func do_jump(duration := 1.0, height := 24.0) -> void:
	var tw = create_tween()
	tw.tween_property(self, "position:y", -height, duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position:y", 0.0, duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	tw.finished.connect(func():
		jump_finished.emit()
	)

# Nodes
func _ready() -> void:
	_sprites = [base, hair, tool_sprite]
	base.animation_finished.connect(_on_base_animation_finished)
	
	_randomize_hair()
	_interact_bar = get_node_or_null("InteractBar")
	_held_sprite = get_node_or_null("HeldItemSprite")
	
	play_state(AnimState.IDLE)

func _process(_delta: float) -> void:
	if not _interact_bar:
		return
	if _locked and _current_state in [AnimState.DOING, AnimState.DIG]:
		_interact_bar.visible = true
		var anim_name = ANIM_NAMES[_current_state]
		if base.sprite_frames and base.sprite_frames.has_animation(anim_name):
			var total_frames = float(base.sprite_frames.get_frame_count(anim_name))
			var current_progress = (float(base.frame) + base.frame_progress) / max(1.0, total_frames)
			_interact_bar.value = current_progress * 100.0
	else:
		_interact_bar.visible = false


func _randomize_hair() -> void:
	var style = HAIR_STYLES.pick_random()
	var new_frames = SpriteFrames.new()
	var base_frames = base.sprite_frames
	
	for anim in base_frames.get_animation_names():
		var expected_suffix = ANIM_STRIPS.get(anim, "")
		if expected_suffix == "":
			continue
			
		var folder_name = anim.to_upper()
		if anim == "walk":
			folder_name = "WALKING"
			
		var tex_path = "res://Assets/Sunnyside_World_ASSET_PACK_V2.1/Sunnyside_World_ASSET_PACK_V2.1/Sunnyside_World_Assets/Characters/Human/%s/%s_%s" % [folder_name, style, expected_suffix]
		var hair_tex = load(tex_path) as Texture2D
		if not hair_tex:
			continue
			
		new_frames.add_animation(anim)
		new_frames.set_animation_loop(anim, base_frames.get_animation_loop(anim))
		new_frames.set_animation_speed(anim, base_frames.get_animation_speed(anim))
			
		for i in range(base_frames.get_frame_count(anim)):
			var base_frame_tex = base_frames.get_frame_texture(anim, i) as AtlasTexture
			if base_frame_tex:
				var new_atlas = AtlasTexture.new()
				new_atlas.atlas = hair_tex
				new_atlas.region = base_frame_tex.region
				new_frames.add_frame(anim, new_atlas, 1.0, i)
				
	hair.sprite_frames = new_frames


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

func play_state(new_state: AnimState) -> void:
	if _locked:
		return
	_current_state = new_state
	_locked = _is_oneshot_state(new_state)
	var anim_name: String = ANIM_NAMES[new_state]
	
	if new_state == AnimState.CARRY and _carry_no_tool:
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
	_update_tool_visibility()


func play_idle() -> void: play_state(AnimState.IDLE)
func play_walk() -> void: play_state(AnimState.WALK)
func play_doing() -> void: play_state_with_speed(AnimState.DOING, 1.0)
func play_dig() -> void: play_state_with_speed(AnimState.DIG, 1.0)
func play_attack() -> void: play_state(AnimState.ATTACK)

## Play a state at a custom speed scale (e.g. 0.5 = 2x slower)
func play_state_with_speed(new_state: AnimState, speed_scale: float) -> void:
	if _locked:
		return
	_current_state = new_state
	_locked = _is_oneshot_state(new_state)
	var anim_name: String = ANIM_NAMES[new_state]
	for sprite in _sprites:
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
			sprite.play(anim_name, speed_scale)
		else:
			sprite.stop()
	_update_flip()
	_update_tool_visibility()


func update_movement_anim(direction: Vector2, is_running := false) -> void:
	if _locked:
		return
	update_direction(direction)
	if direction == Vector2.ZERO:
		var target_idle = AnimState.CARRY if _is_carrying else AnimState.IDLE
		if _current_state != target_idle:
			play_state(target_idle)
			if _is_carrying:
				_pause_all() # Pause carry animation to look like idle
	else:
		var target_move = AnimState.RUN if is_running else AnimState.WALK
		if _is_carrying:
			target_move = AnimState.CARRY
			
		if _current_state != target_move:
			play_state(target_move)
		elif not _is_playing():
			_resume_all()

func set_carrying(carry: bool) -> void:
	_is_carrying = carry
	if not _locked:
		update_movement_anim(_facing_direction)

func show_held_item(icon: Texture2D) -> void:
	if _held_sprite:
		_held_sprite.texture = icon
		_held_sprite.visible = true

func hide_held_item() -> void:
	if _held_sprite:
		_held_sprite.visible = false

func _pause_all() -> void:
	for sprite in _sprites:
		sprite.pause()

func _resume_all() -> void:
	for sprite in _sprites:
		sprite.play()

func _is_playing() -> bool:
	return base.is_playing()

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
	# The "tool" sprite sheet actually contains the character's arms.
	# Hiding it makes the arms disappear completely.
	# We rely on the animation (carry vs carry_no_tool) to hide the tool visually.
	tool_sprite.visible = true


func _is_oneshot_state(state: AnimState) -> bool:
	return state in [AnimState.DOING, AnimState.DIG, AnimState.ATTACK]


func _on_base_animation_finished() -> void:
	if not _locked:
		return
	var finished_state := _current_state
	_locked = false
	animation_state_finished.emit(finished_state)
	var target_idle = AnimState.CARRY if _is_carrying else AnimState.IDLE
	play_state(target_idle)
	if _is_carrying:
		_pause_all()
