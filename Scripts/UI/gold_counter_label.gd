extends Label
class_name GoldCounterLabel

@export var count_speed := 70.0
@export var min_tween_duration := 0.55
@export var max_tween_duration := 1.8	
@export var flash_duration := 0.22
@export var gain_flash_color := Color(1.0, 0.96, 0.68, 1.0)
@export var spend_flash_color := Color(1.0, 0.74, 0.74, 1.0)
@export var text_prefix := "Gold: "
@export var text_suffix := "g"
@export var counter_sfx_path := "res://Assets/SFX/coin_counter.wav"
@export var counter_sfx_volume := -10.0

var _displayed_value := 0.0
var _target_value := 0
var _shown_value := 0
var _initialized := false
var _display_locked := false
var _locked_target_value := 0
var _value_tween: Tween
var _flash_tween: Tween
var _base_modulate := Color.WHITE
var _counter_sfx_player: AudioStreamPlayer


func _ready() -> void:
	_base_modulate = modulate
	_setup_counter_sfx_player()
	set_gold_value(0, true)


func _setup_counter_sfx_player() -> void:
	_counter_sfx_player = AudioStreamPlayer.new()
	add_child(_counter_sfx_player)
	_counter_sfx_player.bus = &"SFX"
	_counter_sfx_player.volume_db = counter_sfx_volume

	var stream := load(counter_sfx_path) as AudioStream
	if not stream:
		return

	var loop_stream := stream.duplicate(true)
	if loop_stream is AudioStreamWAV:
		(loop_stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif loop_stream is AudioStreamOggVorbis:
		(loop_stream as AudioStreamOggVorbis).loop = true

	_counter_sfx_player.stream = loop_stream


func _start_counter_sfx_loop() -> void:
	if not _counter_sfx_player:
		return
	_counter_sfx_player.volume_db = counter_sfx_volume
	if _counter_sfx_player.playing:
		return
	if not _counter_sfx_player.stream:
		return
	_counter_sfx_player.play()


func _stop_counter_sfx_loop() -> void:
	if not _counter_sfx_player:
		return
	if _counter_sfx_player.playing:
		_counter_sfx_player.stop()


func lock_display() -> void:
	_display_locked = true
	_locked_target_value = 0
	_stop_value_tween()
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_initialized = true
	_displayed_value = 0.0
	_target_value = 0
	_shown_value = 0
	_set_label_value(0)
	modulate = _base_modulate


func unlock_display(animate := true) -> void:
	if not _display_locked:
		return

	_display_locked = false
	var target := _locked_target_value
	_locked_target_value = 0

	if animate:
		set_gold_value(target, false)
	else:
		_stop_value_tween()
		_displayed_value = float(target)
		_target_value = target
		_shown_value = target
		_set_label_value(target)


func set_gold_value(amount: int, instant := false) -> void:
	amount = maxi(0, amount)

	if _display_locked:
		_locked_target_value = amount
		if instant:
			_displayed_value = 0.0
			_target_value = amount
			_shown_value = 0
			_set_label_value(0)
		return

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
		_stop_counter_sfx_loop()
		return

	var duration := clampf(diff / maxf(1.0, count_speed), min_tween_duration, max_tween_duration)
	_value_tween = create_tween()
	_value_tween.tween_method(_update_display_value, _displayed_value, float(target_amount), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_value_tween.finished.connect(_stop_counter_sfx_loop, CONNECT_ONE_SHOT)
	_start_counter_sfx_loop()


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
	_stop_counter_sfx_loop()
