extends CanvasLayer


@onready var health_bar: TextureProgressBar = $PlayerHP
@onready var energy_bar: TextureProgressBar = $PlayerEnergy

@export var occlusion_check_interval := 0.12
@export var occlusion_screen_rect := Rect2(Vector2(0, 0), Vector2(150, 110))
@export var faded_alpha := 0.45
@export var alpha_lerp_speed := 9.0
@export var health_main_speed := 260.0
@export var health_trail_speed := 105.0
@export var health_trail_delay := 0.16
@export var energy_smooth_speed := 220.0

var _fade_items: Array[CanvasItem] = []
var _check_timer := 0.0
var _target_alpha := 1.0
var _current_alpha := 1.0
var _health_delayed_bar: TextureProgressBar
var _health_target := 100.0
var _energy_target := 100.0
var _health_trail_delay_timer := 0.0
var _health_base_modulate := Color.WHITE
var _health_flash_tween: Tween


func _ready() -> void:
	_health_delayed_bar = _create_delayed_bar(health_bar, Color(0.33, 0.06, 0.08, 1.0))
	_health_base_modulate = health_bar.modulate
	health_bar.value = 100.0
	energy_bar.value = 100.0
	_health_target = 100.0
	_energy_target = 100.0
	if _health_delayed_bar:
		_health_delayed_bar.value = 100.0
	for child in get_children():
		if child is CanvasItem:
			_fade_items.append(child)
	_set_hud_alpha(1.0)


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= occlusion_check_interval:
		_check_timer = 0.0
		_target_alpha = faded_alpha if _has_occluder_in_hud_area() else 1.0

	_update_bar_animation(delta)
	_current_alpha = move_toward(_current_alpha, _target_alpha, delta * alpha_lerp_speed)
	_set_hud_alpha(_current_alpha)


func update_bars(health_ratio: float, energy_ratio: float) -> void:
	var next_health := clampf(health_ratio * 100.0, health_bar.min_value, health_bar.max_value)
	var next_energy := clampf(energy_ratio * 100.0, energy_bar.min_value, energy_bar.max_value)

	if next_health < _health_target - 0.01:
		_health_trail_delay_timer = health_trail_delay
		_flash_health_bar()
	elif next_health > _health_target + 0.01:
		_health_trail_delay_timer = 0.0
		if _health_delayed_bar:
			_health_delayed_bar.value = next_health

	_health_target = next_health
	_energy_target = next_energy


func _set_hud_alpha(alpha: float) -> void:
	for item in _fade_items:
		if not is_instance_valid(item):
			continue
		var c := item.modulate
		c.a = alpha
		item.modulate = c


func _update_bar_animation(delta: float) -> void:
	health_bar.value = move_toward(health_bar.value, _health_target, delta * health_main_speed)
	if absf(health_bar.value - _health_target) < 0.01:
		health_bar.value = _health_target

	energy_bar.value = move_toward(energy_bar.value, _energy_target, delta * energy_smooth_speed)
	if absf(energy_bar.value - _energy_target) < 0.01:
		energy_bar.value = _energy_target

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

	var flash_color := _health_base_modulate.lerp(Color(1.0, 0.6, 0.6, _health_base_modulate.a), 0.72)
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


func _has_occluder_in_hud_area() -> bool:
	var world_rect := _screen_rect_to_world_rect(occlusion_screen_rect)
	if world_rect.size == Vector2.ZERO:
		return false

	# Extra safety: always check the active player directly.
	var player = PlayerRef.instance
	if player and player is Node2D and player.is_inside_tree():
		if world_rect.has_point(player.global_position):
			return true

	for node in get_tree().get_nodes_in_group("hud_occluders"):
		if not (node is Node2D):
			continue
		var n := node as Node2D
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		if n is CanvasItem and not (n as CanvasItem).visible:
			continue
		if world_rect.has_point(n.global_position):
			return true
	return false


func _screen_rect_to_world_rect(screen_rect: Rect2) -> Rect2:
	var vp := get_viewport()
	if not vp:
		return Rect2(Vector2.ZERO, Vector2.ZERO)

	# Convert screen-space HUD area to world-space using the active canvas transform.
	# This stays correct across camera zoom/stretch settings.
	var to_world := vp.get_canvas_transform().affine_inverse()
	var p0: Vector2 = to_world * screen_rect.position
	var p1: Vector2 = to_world * (screen_rect.position + screen_rect.size)
	var top_left := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y))
	var size := Vector2(absf(p1.x - p0.x), absf(p1.y - p0.y))
	return Rect2(top_left, size)
