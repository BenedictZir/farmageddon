extends Node
class_name DayNightController

## Controls day-night phase switching and updates gameplay multipliers in GameManager.

@export var day_duration_seconds := 45.0
@export var night_duration_seconds := 25.0
@export var transition_duration_seconds := 10.0
@export var night_enemy_spawn_interval_multiplier := 0.7
@export var night_crop_growth_rate_multiplier := 0.5

@export var day_color := Color(1.0, 1.0, 1.0, 1.0)
@export var night_color := Color(0.56, 0.62, 0.78, 1.0)

var _phase_timer := 0.0
var _is_night := false
var _transition_started := false
var _modulate: CanvasModulate
var _fade_tween: Tween


func _ready() -> void:
	_modulate = get_parent().get_node_or_null("DayNightModulate") as CanvasModulate
	if not _modulate:
		push_warning("DayNightController needs a CanvasModulate named DayNightModulate in level root.")
		set_process(false)
		return

	night_color = _modulate.color
	_modulate.color = day_color
	GameManager.set_day_night_modifiers(false, 1.0, 1.0)


func _process(delta: float) -> void:
	var current_phase_duration := night_duration_seconds if _is_night else day_duration_seconds
	var blend_window := minf(transition_duration_seconds, current_phase_duration)
	var remaining := current_phase_duration - _phase_timer

	if not _transition_started and remaining <= blend_window:
		_start_pre_phase_transition(blend_window)

	_phase_timer += delta
	if _phase_timer < current_phase_duration:
		return

	_phase_timer -= current_phase_duration
	_is_night = not _is_night
	_transition_started = false
	_modulate.color = night_color if _is_night else day_color
	_apply_phase_modifiers()


func _start_pre_phase_transition(duration: float) -> void:
	_transition_started = true
	var target_color := day_color if _is_night else night_color
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	if duration <= 0.01:
		_modulate.color = target_color
		return

	_fade_tween = create_tween()
	_fade_tween.tween_property(_modulate, "color", target_color, duration)\
		.set_ease(Tween.EASE_IN_OUT)\
		.set_trans(Tween.TRANS_SINE)


func _apply_phase_modifiers() -> void:

	if _is_night:
		GameManager.set_day_night_modifiers(
			true,
			night_enemy_spawn_interval_multiplier,
			night_crop_growth_rate_multiplier
		)
	else:
		GameManager.set_day_night_modifiers(false, 1.0, 1.0)
