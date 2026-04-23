extends CanvasLayer
class_name TutorialSpotlight
## Reusable spotlight overlay — darkens the screen except for a highlighted area.
## Usage:
##   spotlight.focus_on_control(some_button)
##   spotlight.focus_on_node2d(player, Vector2(60, 60))
##   spotlight.hide_spotlight()

signal spotlight_shown
signal spotlight_hidden

@onready var overlay: ColorRect = $Overlay

var shader_material: ShaderMaterial
var _is_visible := false
var _tween: Tween

@export var default_darkness := 0.85
@export var default_edge_softness := 0.03
@export var default_corner_radius := 0.02
@export var fade_duration := 0.3

enum Shape { RECTANGLE, ELLIPSE }


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	shader_material = overlay.material as ShaderMaterial
	if not shader_material:
		push_error("[TutorialSpotlight] Overlay needs ShaderMaterial!")
		return

	_update_screen_size()
	overlay.visible = false
	get_viewport().size_changed.connect(_update_screen_size)


func _update_screen_size() -> void:
	if shader_material:
		var s := get_viewport().get_visible_rect().size
		shader_material.set_shader_parameter("screen_size", s)


# ── Public API ───────────────────────────────────────────────────────

## Show spotlight at pixel position + size
func show_spotlight(center: Vector2, size: Vector2, animate := true) -> void:
	if not shader_material:
		return
	shader_material.set_shader_parameter("use_pixels", true)
	shader_material.set_shader_parameter("spotlight_center", center)
	shader_material.set_shader_parameter("spotlight_size", size)
	shader_material.set_shader_parameter("darkness", default_darkness)
	shader_material.set_shader_parameter("edge_softness", default_edge_softness)
	shader_material.set_shader_parameter("corner_radius", default_corner_radius)

	if animate:
		_fade_in()
	else:
		overlay.visible = true
		overlay.modulate.a = 1.0
		_is_visible = true
		spotlight_shown.emit()


## Focus on a Control node (Button, Panel, etc.)
func focus_on_control(control: Control, padding := Vector2(20, 20), animate := true) -> void:
	if not control:
		push_warning("[TutorialSpotlight] Control is null!")
		return
	var rect := control.get_global_rect()
	show_spotlight(rect.get_center(), rect.size + padding * 2, animate)


## Focus on a Node2D using canvas transform (screen coords)
func focus_on_node2d(node: Node2D, size := Vector2(80, 80), animate := true) -> void:
	if not node:
		push_warning("[TutorialSpotlight] Node2D is null!")
		return
	var screen_pos: Vector2 = node.get_canvas_transform() * node.global_position
	show_spotlight(screen_pos, size, animate)


## Focus on a screen rect directly
func focus_on_screen_rect(rect: Rect2, padding := Vector2(10, 10), animate := true) -> void:
	show_spotlight(rect.get_center(), rect.size + padding * 2, animate)


## Animate spotlight to new position
func move_to(new_center: Vector2, new_size: Vector2, duration := 0.3) -> void:
	if not shader_material:
		return
	if _tween:
		_tween.kill()

	# Show if hidden
	if not _is_visible:
		overlay.visible = true
		overlay.modulate.a = 1.0
		_is_visible = true

	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_center, _get_center(), new_center, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_size, _get_size(), new_size, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Hide the spotlight
func hide_spotlight(animate := true) -> void:
	if animate:
		_fade_out()
	else:
		overlay.visible = false
		_is_visible = false
		spotlight_hidden.emit()


## Set shape
func set_shape(s: Shape) -> void:
	if shader_material:
		shader_material.set_shader_parameter("shape", 1.0 if s == Shape.ELLIPSE else 0.0)


## Set darkness
func set_darkness(value: float) -> void:
	default_darkness = clampf(value, 0.0, 1.0)
	if shader_material:
		shader_material.set_shader_parameter("darkness", default_darkness)


## Set edge softness
func set_edge_softness(value: float) -> void:
	default_edge_softness = clampf(value, 0.0, 0.5)
	if shader_material:
		shader_material.set_shader_parameter("edge_softness", default_edge_softness)


# ── Internal ─────────────────────────────────────────────────────────

func _set_center(v: Vector2) -> void:
	if shader_material:
		shader_material.set_shader_parameter("spotlight_center", v)

func _get_center() -> Vector2:
	if shader_material:
		return shader_material.get_shader_parameter("spotlight_center")
	return Vector2.ZERO

func _set_size(v: Vector2) -> void:
	if shader_material:
		shader_material.set_shader_parameter("spotlight_size", v)

func _get_size() -> Vector2:
	if shader_material:
		return shader_material.get_shader_parameter("spotlight_size")
	return Vector2.ZERO


func _fade_in() -> void:
	if _tween:
		_tween.kill()
	overlay.visible = true
	overlay.modulate.a = 0.0
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(overlay, "modulate:a", 1.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(func():
		_is_visible = true
		spotlight_shown.emit()
	)


func _fade_out() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(overlay, "modulate:a", 0.0, fade_duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func():
		overlay.visible = false
		_is_visible = false
		spotlight_hidden.emit()
	)
