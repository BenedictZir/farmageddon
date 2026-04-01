extends BaseButton
class_name AnimatedButton

@export var hover_scale_multiplier: float = 1.1
@export var animation_duration: float = 0.1

var _tween: Tween
var _base_scale: Vector2  # Original scale from scene
var _hover_scale: Vector2  # Calculated hover scale

func _ready() -> void:
	# Store the original scale from scene
	_base_scale = scale
	_hover_scale = _base_scale * hover_scale_multiplier
	scale = _base_scale
	
	pivot_offset = size / 2.0
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size / 2.0
	elif what == NOTIFICATION_DISABLED:
		_animate_scale(_base_scale)

func _on_mouse_entered() -> void:
	if disabled:
		return
	#AudioGlobal.start_ui_sfx("res://Assets/SFX/button_hover.wav", [0.97, 1.05])
	CursorManager.set_pointer()
	_animate_scale(_hover_scale)

func _on_mouse_exited() -> void:
	if disabled:
		scale = _base_scale
		return
	CursorManager.set_default()
	_animate_scale(_base_scale)

func _on_pressed() -> void:
	#AudioGlobal.start_ui_sfx("res://Assets/SFX/button_click.wav", [0.97, 1.05], 2)

	if _tween: _tween.kill()
	
	_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_tween.tween_property(self, "scale", _base_scale * 0.95, 0.05)
	_tween.tween_property(self, "scale", _hover_scale, 0.05)

func _animate_scale(target_scale: Vector2) -> void:
	if _tween:
		_tween.kill()
	
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale, animation_duration)
	
func shrink_to_normal() -> void:
	_animate_scale(_base_scale)
