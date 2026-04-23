extends Label
class_name GoldCounterLabel

@export var count_speed := 130.0
@export var min_tween_duration := 0.32
@export var max_tween_duration := 1.1	
@export var flash_duration := 0.22
@export var gain_flash_color := Color(1.0, 0.96, 0.68, 1.0)
@export var spend_flash_color := Color(1.0, 0.74, 0.74, 1.0)
@export var text_prefix := "Gold: "
@export var text_suffix := "g"

var _displayed_value := 0.0
var _target_value := 0
var _shown_value := 0
var _initialized := false
var _value_tween: Tween
var _flash_tween: Tween
var _base_modulate := Color.WHITE


func _ready() -> void:
	_base_modulate = modulate
	set_gold_value(0, true)


func set_gold_value(amount: int, instant := false) -> void:
	amount = maxi(0, amount)

	if not _initialized:
		_initialized = true
		_displayed_value = float(amount)
		_target_value = amount
		_shown_value = amount
		_set_label_value(_shown_value)
		return

	var prev_target := _target_value
	_target_value = amount

	if instant:
		_stop_value_tween()
		_displayed_value = float(amount)
		_shown_value = amount
		_set_label_value(_shown_value)
		return

	_start_value_tween(amount)
	_flash_label(amount >= prev_target)


func _set_label_value(value: int) -> void:
	text = "%s%d%s" % [text_prefix, value, text_suffix]


func _start_value_tween(target_amount: int) -> void:
	_stop_value_tween()

	var diff := absf(float(target_amount) - _displayed_value)
	if diff <= 0.01:
		_displayed_value = float(target_amount)
		_shown_value = target_amount
		_set_label_value(_shown_value)
		return

	var duration := clampf(diff / maxf(1.0, count_speed), min_tween_duration, max_tween_duration)
	_value_tween = create_tween()
	_value_tween.tween_method(_update_display_value, _displayed_value, float(target_amount), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_display_value(value: float) -> void:
	_displayed_value = value
	var next_shown := int(round(value))
	if next_shown == _shown_value:
		return

	_shown_value = next_shown
	_set_label_value(_shown_value)


func _flash_label(is_gain: bool) -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()

	var flash := gain_flash_color if is_gain else spend_flash_color
	modulate = _base_modulate
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", flash, flash_duration * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(self, "modulate", _base_modulate, flash_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _stop_value_tween() -> void:
	if _value_tween and _value_tween.is_running():
		_value_tween.kill()
