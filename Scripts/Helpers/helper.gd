class_name Helper
extends CharacterBody2D

## Base class for NPC helpers (Farmer, Warrior).
## Provides shared movement, health, visual integration, and StateMachine delegation.

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var helper_visual: HelperVisual = $HelperVisual
@onready var state_machine: FiniteStateMachine = $StateMachine
@onready var health_bar: TextureProgressBar = $HelperVisual/HealthBar

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
	health_bar.visible = false
	
	if state_machine:
		state_machine.init(self)

func _physics_process(delta: float) -> void:
	if is_dead or not health_component.is_alive():
		health_bar.visible = false
		return

	# Update Health Bar instantly regardless of state
	health_bar.value = health_component.current_health
	health_bar.visible = true

	if helper_visual.is_locked() and helper_visual.get_current_state() != HelperVisual.AnimState.JUMP:
		velocity = Vector2.ZERO
		return

	if state_machine:
		state_machine.process_physics(delta)
		
	# Heal passive regen (1 HP per second)
	if health_component.current_health < health_component.max_health:
		health_component.heal(1.0 * delta)

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
	HitEffects.play_hit(helper_visual._sprites)

func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	if health_bar:
		health_bar.hide()
	var interact_bar = get_node_or_null("HelperVisual/InteractBar")
	if interact_bar:
		interact_bar.hide()
	if state_machine and state_machine.states.has("death"):
		state_machine.change_state("Death")
	else:
		HitEffects.play_death(self, func(): queue_free())

func _on_revived() -> void:
	is_dead = false
	helper_visual.play_idle()

func start_jump(duration := 1.0, height := 24.0) -> void:
	set_collision_mask_value(1, false)
	helper_visual.do_jump(duration, height)
	if not helper_visual.jump_finished.is_connected(_on_jump_finished):
		helper_visual.jump_finished.connect(_on_jump_finished, CONNECT_ONE_SHOT)

func _on_jump_finished() -> void:
	set_collision_mask_value(1, true)
