class_name Helper
extends CharacterBody2D

## Base class for NPC helpers (Farmer, Warrior).
## Provides shared movement, health, visual integration, and StateMachine delegation.

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var helper_visual: HelperVisual = $HelperVisual
@onready var state_machine: FiniteStateMachine = $StateMachine
@onready var health_bar: TextureProgressBar = $HelperVisual/HealthBar

@export var health_main_speed := 210.0
@export var health_trail_speed := 95.0
@export var health_trail_delay := 0.14
@export var health_regen_delay := 5.0
@export var health_regen_amount_per_second := 1.0

var _health_delayed_bar: TextureProgressBar
var _health_target := 100.0
var _health_trail_delay_timer := 0.0
var _health_regen_delay_timer := 0.0
var _health_base_modulate := Color.WHITE
var _health_flash_tween: Tween

var target_node: Node2D = null
var is_dead := false

func _ready() -> void:
	add_to_group("hud_occluders")
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.revived.connect(_on_revived)
	helper_visual.animation_state_finished.connect(_on_anim_finished)
	
	health_bar.max_value = health_component.max_health
	health_bar.value = health_component.current_health
	_health_target = health_component.current_health
	_health_delayed_bar = _create_delayed_bar(health_bar, Color(0.33, 0.06, 0.08, 1.0))
	if _health_delayed_bar:
		_health_delayed_bar.value = health_component.current_health
	_health_base_modulate = health_bar.modulate
	health_bar.visible = false
	_health_regen_delay_timer = maxf(0.0, health_regen_delay)
	
	if state_machine:
		state_machine.init(self)

func _physics_process(delta: float) -> void:
	if is_dead or not health_component.is_alive():
		health_bar.visible = false
		if _health_delayed_bar:
			_health_delayed_bar.visible = false
		return

	_update_health_bar_state(delta)
	health_bar.visible = true
	if _health_delayed_bar:
		_health_delayed_bar.visible = true

	if helper_visual.is_locked() and helper_visual.get_current_state() != HelperVisual.AnimState.JUMP:
		velocity = Vector2.ZERO
		return

	if state_machine:
		state_machine.process_physics(delta)

	if _health_regen_delay_timer > 0.0:
		_health_regen_delay_timer = maxf(0.0, _health_regen_delay_timer - delta)
	elif health_component.current_health < health_component.max_health:
		health_component.heal(health_regen_amount_per_second * delta)

func _process(delta: float) -> void:
	if is_dead:
		return
	if state_machine:
		state_machine.process_frame(delta)

func _on_anim_finished(state: HelperVisual.AnimState) -> void:
	if state_machine and state_machine.current_state and state_machine.current_state.has_method("on_animation_finished"):
		state_machine.current_state.on_animation_finished(state)

func _on_damaged(_amount: float) -> void:
	if is_dead or not health_component.is_alive():
		return
	_health_trail_delay_timer = health_trail_delay
	_health_regen_delay_timer = maxf(0.0, health_regen_delay)
	_flash_health_bar()
	HitEffects.play_hit(helper_visual._sprites)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if health_bar:
		health_bar.hide()
	if _health_delayed_bar:
		_health_delayed_bar.hide()
	var interact_bar = get_node_or_null("HelperVisual/InteractBar")
	if interact_bar:
		interact_bar.hide()
	if state_machine and state_machine.states.has("death"):
		state_machine.change_state("Death")
	else:
		HitEffects.play_death(self, func(): queue_free())

func _on_revived() -> void:
	is_dead = false
	_health_target = health_component.current_health
	health_bar.value = _health_target
	if _health_delayed_bar:
		_health_delayed_bar.value = _health_target
	helper_visual.play_idle()

func start_jump(duration := 1.0, height := 24.0) -> void:
	set_collision_mask_value(1, false)
	helper_visual.do_jump(duration, height)
	if not helper_visual.jump_finished.is_connected(_on_jump_finished):
		helper_visual.jump_finished.connect(_on_jump_finished, CONNECT_ONE_SHOT)

func _on_jump_finished() -> void:
	set_collision_mask_value(1, true)


func _update_health_bar_state(delta: float) -> void:
	_health_target = clampf(health_component.current_health, health_bar.min_value, health_bar.max_value)
	health_bar.value = move_toward(health_bar.value, _health_target, delta * health_main_speed)
	if absf(health_bar.value - _health_target) < 0.01:
		health_bar.value = _health_target

	if not _health_delayed_bar:
		return

	if _health_delayed_bar.value < health_bar.value:
		_health_delayed_bar.value = health_bar.value
		return

	if _health_delayed_bar.value <= health_bar.value + 0.01:
		_health_delayed_bar.value = health_bar.value
		return

	if _health_trail_delay_timer > 0.0:
		_health_trail_delay_timer = maxf(0.0, _health_trail_delay_timer - delta)
		return

	_health_delayed_bar.value = move_toward(_health_delayed_bar.value, health_bar.value, delta * health_trail_speed)


func _flash_health_bar() -> void:
	if _health_flash_tween and _health_flash_tween.is_running():
		_health_flash_tween.kill()

	var flash_color := _health_base_modulate.lerp(Color(1.0, 0.6, 0.6, _health_base_modulate.a), 0.68)
	health_bar.modulate = _health_base_modulate
	_health_flash_tween = create_tween()
	_health_flash_tween.tween_property(health_bar, "modulate", flash_color, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_health_flash_tween.tween_property(health_bar, "modulate", _health_base_modulate, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _create_delayed_bar(main_bar: TextureProgressBar, tint: Color) -> TextureProgressBar:
	if not main_bar or not main_bar.get_parent():
		return null

	var delayed := TextureProgressBar.new()
	delayed.name = "%sDelayed" % main_bar.name
	delayed.offset_left = main_bar.offset_left
	delayed.offset_top = main_bar.offset_top
	delayed.offset_right = main_bar.offset_right
	delayed.offset_bottom = main_bar.offset_bottom
	delayed.scale = main_bar.scale
	delayed.z_index = main_bar.z_index - 1
	delayed.min_value = main_bar.min_value
	delayed.max_value = main_bar.max_value
	delayed.step = main_bar.step
	delayed.value = main_bar.value
	delayed.texture_progress = main_bar.texture_progress
	delayed.texture_under = null
	delayed.texture_over = null
	delayed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	delayed.modulate = tint

	var parent := main_bar.get_parent()
	parent.add_child(delayed)
	parent.move_child(delayed, main_bar.get_index())
	return delayed
