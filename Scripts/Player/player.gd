extends CharacterBody2D

const FLOATING_TEXT_SCENE := preload("res://Scenes/UI/floating_text.tscn")

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var player_visual: Node2D = $PlayerVisual
@onready var select_box: Node2D = $SelectBox
@onready var hud: CanvasLayer = $HUD
@onready var attack_component: Area2D = $Components/AttackComponent
@onready var inventory: PlayerInventory = $Components/Inventory

var direction := Vector2.ZERO
var is_running := false
var is_knocked := false
var is_rolling := false
var _roll_velocity := Vector2.ZERO
var _time_since_last_damage := 0.0

## Proxied from inventory — select_box reads this
var is_carrying: bool:
	get: return inventory.is_carrying if inventory else false
var _held_item: Resource:
	get: return inventory.get_held_item() if inventory else null
var _is_holding_product: bool:
	get: return inventory.is_holding_product() if inventory else false

@export var max_energy := 100.0
var energy := 100.0
var _sprint_locked_out := false

@export var roll_energy_cost := 20.0
@export var roll_distance := 32.0
@export var roll_duration := 0.3
@export var attack_hit_shake_magnitude := 1.4
@export var attack_hit_shake_duration := 0.12


func _ready() -> void:
	add_to_group("hud_occluders")
	PlayerRef.register(self)
	tree_exiting.connect(func(): PlayerRef.unregister(self))
	inventory.setup(self, select_box, player_visual)
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.revived.connect(_on_revived)
	player_visual.animation_state_finished.connect(_on_anim_state_finished)
	if attack_component.has_signal("hit_landed") and not attack_component.hit_landed.is_connected(_on_attack_hit_landed):
		attack_component.hit_landed.connect(_on_attack_hit_landed)
	if CurrencyManager.has_signal("gold_spent") and not CurrencyManager.gold_spent.is_connected(_on_gold_spent):
		CurrencyManager.gold_spent.connect(_on_gold_spent)


func _unhandled_input(event: InputEvent) -> void:
	if is_knocked or player_visual.is_locked():
		return

	if event is InputEventMouseButton and _is_mouse_over_ui():
		return

	if event.is_action_pressed("attack"):
		_do_attack()
	elif event.is_action_pressed("roll"):
		_do_roll()
	elif event.is_action_pressed("interact"):
		inventory.interact()
	elif event.is_action_pressed("drop"):
		inventory.drop()


func _physics_process(delta: float) -> void:
	if is_knocked:
		return

	_update_energy(delta)
	_update_health(delta)
	_handle_movement()

	hud.update_bars(
		health_component.current_health / health_component.max_health,
		energy / max_energy
	)


func _update_energy(delta: float) -> void:
	var shift_held := Input.is_action_pressed("run")
	if not shift_held:
		_sprint_locked_out = false

	is_running = (
		shift_held
		and not _sprint_locked_out
		and not player_visual.is_locked()
		and energy > 0
		and direction != Vector2.ZERO
	)

	if is_running:
		energy = max(0.0, energy - delta * 20.0)
		if energy <= 0.0:
			_sprint_locked_out = true
			is_running = false
	elif not is_rolling:
		energy = min(energy + delta * 20.0, max_energy)


func _update_health(delta: float) -> void:
	_time_since_last_damage += delta
	if _time_since_last_damage >= 5.0 and health_component.current_health < health_component.max_health:
		health_component.heal(delta * 5.0)


func _handle_movement() -> void:
	if is_rolling:
		velocity = _roll_velocity
		move_and_slide()
		return

	if player_visual.is_locked():
		velocity = Vector2.ZERO
		return

	direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	movement_component.move(self, direction, is_running)
	player_visual.update_movement_anim(direction, is_carrying, is_running)


func _do_attack() -> void:
	velocity = Vector2.ZERO
	player_visual.play_attack()
	attack_component.activate(player_visual.base.flip_h)


func _do_roll() -> void:
	if energy < roll_energy_cost:
		return
	energy -= roll_energy_cost
	is_rolling = true
	set_collision_layer_value(2, false)
	player_visual.play_roll()
	var roll_dir := direction.normalized() if direction != Vector2.ZERO \
		else (Vector2.LEFT if player_visual.base.flip_h else Vector2.RIGHT)
	_roll_velocity = roll_dir * (roll_distance / roll_duration)
	get_tree().create_timer(roll_duration).timeout.connect(_end_roll_dash)


func _end_roll_dash() -> void:
	_roll_velocity = Vector2.ZERO


## Called by shop_item.gd
func hold_item(item: Resource, item_size := Vector2i(1, 1)) -> void:
	inventory.hold_item(item, item_size)


func _on_damaged(_amount: float) -> void:
	_time_since_last_damage = 0.0
	if is_knocked:
		return
	var camera = get_viewport().get_camera_2d()
	HitEffects.play_hit(player_visual._sprites, camera)


func _on_attack_hit_landed(_target: Node2D) -> void:
	if is_knocked:
		return
	var camera := get_viewport().get_camera_2d()
	HitEffects.play_camera_shake(camera, attack_hit_shake_magnitude, attack_hit_shake_duration)


func _on_died() -> void:
	is_knocked = true
	is_rolling = false
	_roll_velocity = Vector2.ZERO
	set_collision_layer_value(2, true)
	attack_component.deactivate()
	velocity = Vector2.ZERO
	# Drop 50% gold
	var gold_to_drop := CurrencyManager.gold / 2
	if gold_to_drop > 0:
		CurrencyManager.spend_gold(gold_to_drop)
	# Drop held item
	inventory.drop()
	player_visual.play_death()


func _on_revived() -> void:
	is_knocked = false
	player_visual.play_idle()


func _on_anim_state_finished(state) -> void:
	if state == player_visual.AnimState.ATTACK:
		attack_component.deactivate()

	if state == player_visual.AnimState.ROLL:
		is_rolling = false
		_roll_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		set_collision_layer_value(2, true)

	if state == player_visual.AnimState.DIG or state == player_visual.AnimState.DOING:
		inventory.on_interact_anim_finished()

	if state == player_visual.AnimState.DEATH:
		get_tree().create_timer(5.0).timeout.connect(func():
			health_component.revive()
		)


func _on_gold_spent(amount: int) -> void:
	if amount <= 0:
		return
	_spawn_currency_text("-%d" % amount, Color(1.0, 0.234, 0.271, 1.0))


func _spawn_currency_text(text: String, color: Color) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var ft = FLOATING_TEXT_SCENE.instantiate()
	get_parent().add_child(ft)
	ft.global_position = global_position + Vector2(0, -18)
	ft.setup(text, color)


func _is_mouse_over_ui() -> bool:
	var viewport := get_viewport()
	return viewport.gui_get_hovered_control() != null
