extends Control

## Shop UI that slides in/out. Triggered by:
## - Tab key toggle
## - Mouse entering/leaving the shop area

@onready var bar: Node2D = $Bar

var _is_visible := false
var _tween: Tween
var toggled_by_tab := false
@export var bar_height := 72.0  # how far to slide up when hiding
@export var hover_margin := 20.0  # extra pixels below bar that still count as "in shop"
@export var show_duration := 0.24
@export var hide_duration := 0.2
@export var closed_alpha := 0.35
@export var closed_scale := Vector2(0.985, 0.985)
@export var opened_scale := Vector2.ONE

func _ready() -> void:
	# Start hidden
	_is_visible = false
	bar.position.y = -bar_height
	bar.modulate.a = closed_alpha
	bar.scale = closed_scale


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop_toggle") and GameManager.is_input_unlocked("shop_toggle"):
		toggle()


func _process(_delta: float) -> void:
	if _is_visible and not toggled_by_tab:
		# Auto-hide when mouse leaves shop area
		var mouse_y := get_global_mouse_position().y
		if mouse_y > bar_height + hover_margin:
			slide_out()
	else:
		# Auto-show when mouse enters top area (blocked during tutorial)
		if not GameManager.is_input_unlocked("shop_toggle"):
			return
		var mouse_y := get_global_mouse_position().y
		if mouse_y < hover_margin:
			slide_in()


func toggle() -> void:
	if _is_visible:
		toggled_by_tab = false
		AudioGlobal.start_ui_sfx("res://Assets/SFX/shop_open.wav", [0.97, 1.02], -10)
		slide_out()
	else:
		toggled_by_tab = true
		slide_in()
		AudioGlobal.start_ui_sfx("res://Assets/SFX/shop_close.wav", [0.97, 1.02], -10)


func slide_in() -> void:
	if _is_visible:
		return
	_is_visible = true
	_animate_bar(0.0, show_duration, Tween.EASE_OUT, Tween.TRANS_BACK, 1.0, opened_scale)


func slide_out() -> void:
	if not _is_visible:
		return
	_is_visible = false
	_animate_bar(-bar_height, hide_duration, Tween.EASE_IN, Tween.TRANS_CUBIC, closed_alpha, closed_scale)


func _animate_bar(target_y: float, duration: float, ease: Tween.EaseType, trans: Tween.TransitionType, target_alpha: float, target_scale: Vector2) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(bar, "position:y", target_y, duration).set_ease(ease).set_trans(trans)
	_tween.parallel().tween_property(bar, "modulate:a", target_alpha, duration).set_ease(ease).set_trans(Tween.TRANS_QUAD)
	_tween.parallel().tween_property(bar, "scale", target_scale, duration).set_ease(ease).set_trans(Tween.TRANS_QUAD)
