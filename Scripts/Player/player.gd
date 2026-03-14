extends CharacterBody2D

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var player_visual: Node2D = $PlayerVisual
@onready var select_box: Node2D = $SelectBox
@onready var hud: CanvasLayer = $HUD
@onready var attack_component: Area2D = $Components/AttackComponent

var direction := Vector2.ZERO
var is_carrying := false
var is_running := false
var is_knocked := false
var is_rolling := false
var _roll_velocity := Vector2.ZERO

var _held_item: Resource = null    # CropData, or any placeable resource
var _target_tile: Node2D = null    # tile we're about to place on

@export var max_energy := 100.0
var energy := 100.0
var _sprint_locked_out := false

@export var roll_energy_cost := 20.0
@export var roll_distance := 32.0
@export var roll_duration := 0.3


func _ready() -> void:
	PlayerRef.register(self)
	tree_exiting.connect(func(): PlayerRef.unregister(self))
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.revived.connect(_on_revived)
	player_visual.animation_state_finished.connect(_on_anim_state_finished)


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
		_do_interact()
	elif event.is_action_pressed("drop"):
		_do_drop()


func _physics_process(delta: float) -> void:
	if is_knocked:
		return

	_update_energy(delta)
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


func _do_interact() -> void:
	if is_carrying and _held_item:
		_try_place_item()
	else:
		player_visual.play_doing()


func _do_drop() -> void:
	if is_carrying:
		_clear_held_item()


func _try_place_item() -> void:
	var tile = select_box.current_target
	if not tile:
		return
	if tile.has_method("accepts_type") and _held_item.get("placeable_type") != null \
		and tile.accepts_type(_held_item.placeable_type):
		_target_tile = tile
		velocity = Vector2.ZERO
		player_visual.play_dig()
	else:
		select_box.play_error()


func hold_item(item: Resource, item_size := Vector2i(1, 1)) -> void:
	_held_item = item
	is_carrying = true
	select_box.set_size(item_size)


func _clear_held_item() -> void:
	is_carrying = false
	_held_item = null
	_target_tile = null


func pick_up_item(item_size := Vector2i(1, 1)) -> void:
	is_carrying = true
	select_box.set_size(item_size)


func place_item() -> void:
	if not is_carrying:
		return
	select_box.play_placing()
	player_visual.play_doing()
	_clear_held_item()


func _on_damaged(_amount: float) -> void:
	if is_knocked:
		return
	player_visual.play_hurt()


func _on_died() -> void:
	is_knocked = true
	velocity = Vector2.ZERO
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

	# After dig animation → place item on tile
	if state == player_visual.AnimState.DIG:
		if _target_tile and _held_item:
			if _held_item is CropData:
				_target_tile.plant_crop(_held_item)
			select_box.play_placing()
			_clear_held_item()

	if state == player_visual.AnimState.DEATH:
		get_tree().create_timer(2.0).timeout.connect(func():
			health_component.revive()
		)


func _is_mouse_over_ui() -> bool:
	var viewport := get_viewport()
	return viewport.gui_get_hovered_control() != null
