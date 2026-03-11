extends CharacterBody2D

@onready var movement_component: Node2D = $Components/MovementComponent
@onready var health_component: Node2D = $Components/HealthComponent
@onready var player_visual: Node2D = $PlayerVisual
@onready var select_box: Node2D = $SelectBox

var direction := Vector2.ZERO
var is_carrying := false  # true when holding an item in the item slot
var is_running := false
var is_knocked := false   # true during death/knock state

# Energy for running
@export var max_energy := 100.0
var energy := 100.0
var _sprint_locked_out := false  # true when energy hit 0, reset on shift release


func _ready() -> void:
	health_component.damaged.connect(_on_damaged)
	health_component.died.connect(_on_died)
	health_component.revived.connect(_on_revived)
	player_visual.animation_state_finished.connect(_on_anim_state_finished)


func _physics_process(delta: float) -> void:
	if is_knocked:
		return
	
	_handle_input()
	
	# Sprint lockout: once energy hits 0, must release shift before sprinting again
	var shift_held := Input.is_action_pressed("run")
	if not shift_held:
		_sprint_locked_out = false
	
	is_running = shift_held and not _sprint_locked_out and energy > 0 and direction != Vector2.ZERO
	
	if is_running:
		energy = max(0, energy - delta * 20.0)
		if energy <= 0:
			_sprint_locked_out = true
			is_running = false
	else:
		energy = min(energy + delta * 10.0, max_energy)
	
	movement_component.move(self, direction, is_running)
	player_visual.update_movement_anim(direction, is_carrying, is_running)
	
	# Update select box visibility
	if is_carrying:
		select_box.show_selecting()


func _handle_input() -> void:
	direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)


func pick_up_item(item_size := Vector2i(1, 1)) -> void:
	is_carrying = true
	select_box.set_size(item_size)
	select_box.show_selecting()


func place_item() -> void:
	if not is_carrying:
		return
	is_carrying = false
	select_box.play_placing()
	player_visual.play_doing()


func do_interact() -> void:
	player_visual.play_doing()


## Call this to perform planting
func do_dig() -> void:
	player_visual.play_dig()


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
	# After death animation, wait then revive (knock mechanic)
	if state == player_visual.AnimState.DEATH:
		# Start a knock timer — player revives after a delay
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			health_component.revive()
		)
