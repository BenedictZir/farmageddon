extends Node

const DEFAULT_BUS := &"SFX"


func start_sfx(sfx_position: Node, sfx_path: String, pitch_randomizer: Array = [1.0, 1.0], volume: float = 0.0, start_at: float = 0.0) -> void:
	if not sfx_position or not is_instance_valid(sfx_position):
		return

	var stream := _load_stream(sfx_path)
	if not stream:
		return

	var speaker := AudioStreamPlayer2D.new()
	sfx_position.add_child(speaker)
	speaker.stream = stream
	speaker.bus = DEFAULT_BUS
	speaker.pitch_scale = _pick_pitch(pitch_randomizer)
	speaker.volume_db = volume
	speaker.play(start_at)
	await speaker.finished
	speaker.queue_free()


func start_ui_sfx(sfx_path: String, pitch_randomizer: Array = [1.0, 1.0], volume: float = 0.0, start_at: float = 0.0, bus: String = "SFX") -> void:
	var stream := _load_stream(sfx_path)
	if not stream:
		return

	var speaker := AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = stream
	speaker.bus = &"Music" if bus != "SFX" else DEFAULT_BUS
	speaker.pitch_scale = _pick_pitch(pitch_randomizer)
	speaker.volume_db = volume
	speaker.play(start_at)

	await speaker.finished
	speaker.queue_free()


func start_card_sfx(sfx: AudioStream, pitch_randomizer: Array = [1.0, 1.0], volume: float = 0.0, start_at: float = 0.0) -> void:
	if not sfx:
		return

	var speaker := AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = sfx
	speaker.bus = DEFAULT_BUS
	speaker.pitch_scale = _pick_pitch(pitch_randomizer)
	speaker.volume_db = volume
	speaker.play(start_at)

	await speaker.finished
	speaker.queue_free()


func start_loop_sfx(sfx_path: String, pitch_randomizer: Array = [1.0, 1.0], volume: float = 0.0, start_at: float = 0.0) -> AudioStreamPlayer:
	var stream := _load_stream(sfx_path)
	if not stream:
		return null

	var speaker := AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = stream
	speaker.bus = DEFAULT_BUS
	speaker.pitch_scale = _pick_pitch(pitch_randomizer)
	speaker.volume_db = volume
	speaker.play(start_at)
	return speaker


func reset() -> void:
	for child in get_children():
		child.queue_free()


func _load_stream(path: String) -> AudioStream:
	var stream := load(path) as AudioStream
	if not stream:
		push_warning("Audio stream missing or invalid: %s" % path)
	return stream


func _pick_pitch(pitch_randomizer: Array) -> float:
	if pitch_randomizer.size() < 2:
		return 1.0
	return randf_range(float(pitch_randomizer[0]), float(pitch_randomizer[1]))
	
