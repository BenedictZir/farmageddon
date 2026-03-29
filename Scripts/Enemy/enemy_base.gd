extends CharacterBody2D
class_name EnemyBase

## Base class for enemies. Provides shared references and death logic.

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
var attack_cooldown := 0.0


var is_dead := false
var interruptible := true


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
	if interact_bar:
		interact_bar.visible = false
		

func _on_damaged(amount:= 0.0) -> void:
	if health_bar:
		health_bar.value = health_component.current_health
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
	if health_bar:
		health_bar.value = health_component.current_health


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true
	_on_death()


## Override in subclasses for custom death behavior
func _on_death() -> void:
	if health_bar:
		health_bar.hide()
	if interact_bar:
		interact_bar.hide()
	velocity = Vector2.ZERO
	attack_component.deactivate()
	if fsm and fsm.states.has("death"):
		fsm.change_state("Death")
	else:
		HitEffects.play_death(self, func(): queue_free())


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
	attack_cooldown -= delta
	fsm.process_physics(delta)


func _process(delta: float) -> void:
	fsm.process_frame(delta)

func _on_visual_anim_finished(anim_name: String) -> void:
	if anim_name == "attack":
		attack_component.deactivate()
