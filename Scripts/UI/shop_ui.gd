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

const SHOW_DURATION := 0.35
const HIDE_DURATION := 0.25


func _ready() -> void:
	# Start hidden
	_is_visible = false
	bar.position.y = -bar_height


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shop_toggle"):
		toggle()


func _process(_delta: float) -> void:
	if _is_visible and not toggled_by_tab:
		# Auto-hide when mouse leaves shop area
		var mouse_y := get_global_mouse_position().y
		if mouse_y > bar_height + hover_margin:
			slide_out()
	else:
		# Auto-show when mouse enters top area
		var mouse_y := get_global_mouse_position().y
		if mouse_y < hover_margin:
			slide_in()


func toggle() -> void:
	if _is_visible:
		toggled_by_tab = false
		slide_out()
	else:
		toggled_by_tab = true
		slide_in()


func slide_in() -> void:
	if _is_visible:
		return
	_is_visible = true
	_animate_bar(0.0, SHOW_DURATION, Tween.EASE_OUT, Tween.TRANS_BACK)


func slide_out() -> void:
	if not _is_visible:
		return
	_is_visible = false
	_animate_bar(-bar_height, HIDE_DURATION, Tween.EASE_IN, Tween.TRANS_CUBIC)


func _animate_bar(target_y: float, duration: float, ease: Tween.EaseType, trans: Tween.TransitionType) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(bar, "position:y", target_y, duration)\
		.set_ease(ease).set_trans(trans)
