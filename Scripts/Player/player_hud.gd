extends CanvasLayer


@onready var health_bar: TextureProgressBar = $PlayerHP
@onready var energy_bar: TextureProgressBar = $PlayerEnergy

@export var tween_speed := 0.3
@export var occlusion_check_interval := 0.12
@export var occlusion_screen_rect := Rect2(Vector2(0, 0), Vector2(150, 110))
@export var faded_alpha := 0.45
@export var alpha_lerp_speed := 9.0

var _health_tween: Tween
var _energy_tween: Tween
var _fade_items: Array[CanvasItem] = []
var _check_timer := 0.0
var _target_alpha := 1.0
var _current_alpha := 1.0


func _ready() -> void:
	health_bar.value = 100.0
	energy_bar.value = 100.0
	for child in get_children():
		if child is CanvasItem:
			_fade_items.append(child)
	_set_hud_alpha(1.0)


func _process(delta: float) -> void:
	_check_timer += delta
	if _check_timer >= occlusion_check_interval:
		_check_timer = 0.0
		_target_alpha = faded_alpha if _has_occluder_in_hud_area() else 1.0

	_current_alpha = move_toward(_current_alpha, _target_alpha, delta * alpha_lerp_speed)
	_set_hud_alpha(_current_alpha)


func update_bars(health_ratio: float, energy_ratio: float) -> void:
	_smooth_set(health_bar, health_ratio * 100.0, "_health_tween")
	_smooth_set(energy_bar, energy_ratio * 100.0, "_energy_tween")


func _smooth_set(bar: TextureProgressBar, target: float, tween_var: String) -> void:
	if absf(bar.value - target) < 0.01:
		bar.value = target
		return

	# If difference is small (e.g. passive regen) or we're basically keeping up,
	# don't start a new tween since starting a tween every frame stutters.
	if absf(bar.value - target) <= 2.0:
		var existing: Tween = get(tween_var)
		if existing and existing.is_running():
			existing.kill()
		bar.value = target
		return

	# Large damage/heal: use tween
	var existing: Tween = get(tween_var)
	if existing and existing.is_running():
		existing.kill()

	var tw := create_tween()
	tw.tween_property(bar, "value", target, tween_speed)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	set(tween_var, tw)


func _set_hud_alpha(alpha: float) -> void:
	for item in _fade_items:
		if not is_instance_valid(item):
			continue
		var c := item.modulate
		c.a = alpha
		item.modulate = c


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
