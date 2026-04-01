extends CharacterBody2D
class_name EnemyBase

## Base class for enemies. Provides shared references and death logic.

const FLOATING_TEXT_SCENE := preload("res://Scenes/UI/floating_text.tscn")

@onready var movement_component: MovementComponent = $Components/MovementComponent
@onready var health_component: HealthComponent = $Components/HealthComponent
@onready var attack_component: Area2D = $Components/AttackComponent
@onready var visual: EnemyVisual = $EnemyVisual
@onready var fsm: FiniteStateMachine = $StateMachine

@onready var interact_bar: TextureProgressBar = $InteractBar
@onready var health_bar: TextureProgressBar = $EnemyVisual/HealthBar

@export var player_detect_range := 80.0
@export var attack_range := 16.0
@export var attack_stop_range := 20.0
@export var run_speed := 45.0
@export var walk_speed := 25.0
@export var roam_change_interval := 2.0
@export var gold_drop_min := 0
@export var gold_drop_max := 0
@export var health_main_speed := 220.0
@export var health_trail_speed := 100.0
@export var health_trail_delay := 0.14
@export var target_scan_interval := 0.18
var attack_cooldown := 0.0


var is_dead := false
var interruptible := true
var _health_delayed_bar: TextureProgressBar
var _health_target := 100.0
var _health_trail_delay_timer := 0.0
var _health_base_modulate := Color.WHITE
var _health_flash_tween: Tween
var _target_scan_timer := 0.0
var _cached_helpers: Array[Node2D] = []


func _ready() -> void:
	add_to_group("hud_occluders")
	fsm.init(self)
	visual.anim_finished.connect(_on_visual_anim_finished)
	
	movement_component.movement_speed = run_speed
	health_component.died.connect(_on_died)
	health_component.damaged.connect(_on_damaged)
	if health_component.has_signal("healed"):
		health_component.healed.connect(_on_healed)
		
	if health_bar:
		health_bar.max_value = health_component.max_health
		health_bar.value = health_component.current_health
		_health_target = health_component.current_health
		_health_delayed_bar = _create_delayed_bar(health_bar, Color(0.33, 0.06, 0.08, 1.0))
		if _health_delayed_bar:
			_health_delayed_bar.value = health_component.current_health
		_health_base_modulate = health_bar.modulate
	if interact_bar:
		interact_bar.visible = false
		

func _on_damaged(amount:= 0.0) -> void:
	_health_trail_delay_timer = health_trail_delay
	_flash_health_bar()
	if is_dead:
		return
	# Flash should still play even in non-interruptible states (e.g. goblin stealing).
	HitEffects.play_hit([visual])
	if not interruptible:
		return
	# If attack animation is already locked, keep the hitbox active so the swing can still land.
	if visual and visual.is_locked():
		return
	attack_component.deactivate()
	

func _on_healed(amount:= 0.0) -> void:
		_health_trail_delay_timer = 0.0
		if _health_delayed_bar and health_component.current_health > _health_delayed_bar.value:
			_health_delayed_bar.value = health_component.current_health


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_on_death()


## Override in subclasses for custom death behavior
func _on_death() -> void:
	if health_bar:
		health_bar.hide()
	if _health_delayed_bar:
		_health_delayed_bar.hide()
	if interact_bar:
		interact_bar.hide()
	velocity = Vector2.ZERO
	attack_component.deactivate()
	_drop_gold_on_death()
	if fsm and fsm.states.has("death"):
		fsm.change_state("Death")
	else:
		HitEffects.play_death(self, func(): queue_free())


func _drop_gold_on_death() -> void:
	if gold_drop_max <= 0:
		return

	var min_drop := clampi(gold_drop_min, 0, gold_drop_max)
	var amount := randi_range(min_drop, gold_drop_max)
	if amount <= 0:
		return

	CurrencyManager.add_gold(amount)
	_show_gold_popup(amount)


func _show_gold_popup(amount: int) -> void:
	var root := get_tree().current_scene
	if not root:
		return

	var popup = FLOATING_TEXT_SCENE.instantiate()
	popup.setup("+%dg" % amount, Color.GOLD)
	root.add_child(popup)
	popup.global_position = global_position + Vector2(0, -14)


func set_interact_progress(progress: float, is_visible := true) -> void:
	if interact_bar:
		interact_bar.value = progress * 100.0
		interact_bar.visible = is_visible






func update_flip(dir: Vector2) -> void:
	visual.update_flip(dir)


func start_jump(duration := 1.0, height := 24.0) -> void:
	# Disable collision mask 1 (World/Fences) so we can jump over them
	set_collision_mask_value(1, false)
	visual.do_jump(duration, height)
	visual.jump_finished.connect(_on_jump_finished, CONNECT_ONE_SHOT)

func _on_jump_finished() -> void:
	# Re-enable collision mask 1
	set_collision_mask_value(1, true)

func do_attack() -> void:
	attack_cooldown = 1.5
	visual.play_anim_locked("attack")
	attack_component.activate(visual.flip_h)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_health_bar_state(delta)
	_update_target_cache(delta)
	attack_cooldown -= delta
	fsm.process_physics(delta)


func _process(delta: float) -> void:
	fsm.process_frame(delta)

func _on_visual_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		attack_component.deactivate()


func _update_health_bar_state(delta: float) -> void:
	if not health_bar:
		return
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
	if not health_bar:
		return
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


func get_combat_targets() -> Array[Node2D]:
	var targets: Array[Node2D] = []
	var player := PlayerRef.instance
	if player and not player.is_knocked:
		targets.append(player as Node2D)

	for helper in _cached_helpers:
		if not is_instance_valid(helper):
			continue
		if bool(helper.get("is_dead")):
			continue
		targets.append(helper)

	return targets


func _update_target_cache(delta: float) -> void:
	_target_scan_timer -= delta
	if _target_scan_timer > 0.0:
		return

	_target_scan_timer = maxf(0.05, target_scan_interval)
	_cached_helpers.clear()

	for node in get_tree().get_nodes_in_group("helpers"):
		if node is Node2D:
			_cached_helpers.append(node)
