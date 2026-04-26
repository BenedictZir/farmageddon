extends Node
#script by viscasa.itch.io
const DEFAULT_BUS := &"SFX"
var bgm: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bgm = AudioStreamPlayer.new()
	add_child(bgm)
	bgm.volume_db = -10.0
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


func start_ui_sfx_reversed(sfx_path: String, pitch_randomizer: Array = [1.0, 1.0], volume: float = 0.0, bus: String = "SFX") -> void:
	var stream := _load_stream(sfx_path)
	if not stream:
		return

	var use_reverse_playback_fallback := false
	if stream is AudioStreamWAV:
		var reversed_stream := _build_reversed_wav_stream(stream as AudioStreamWAV)
		if reversed_stream:
			stream = reversed_stream
		else:
			use_reverse_playback_fallback = true
	else:
		use_reverse_playback_fallback = true

	if use_reverse_playback_fallback:
		start_ui_sfx(sfx_path, pitch_randomizer, volume, 0.0, bus)
		return

	var speaker := AudioStreamPlayer.new()
	add_child(speaker)
	speaker.stream = stream
	speaker.bus = &"Music" if bus != "SFX" else DEFAULT_BUS
	speaker.volume_db = volume
	speaker.pitch_scale = _pick_pitch(pitch_randomizer)
	speaker.play()

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

	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

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


func _build_reversed_wav_stream(source: AudioStreamWAV) -> AudioStreamWAV:
	var frame_bytes := _get_wav_frame_bytes(source)
	if frame_bytes <= 0:
		return null

	var src_data := source.data
	var frame_count := src_data.size() / frame_bytes
	if frame_count <= 1:
		return null

	var reversed := PackedByteArray()
	reversed.resize(frame_count * frame_bytes)

	for i in range(frame_count):
		var src_offset := (frame_count - 1 - i) * frame_bytes
		var dst_offset := i * frame_bytes
		for b in range(frame_bytes):
			reversed[dst_offset + b] = src_data[src_offset + b]

	var out := source.duplicate(true) as AudioStreamWAV
	out.data = reversed
	out.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return out


func _get_wav_frame_bytes(stream: AudioStreamWAV) -> int:
	var bytes_per_sample := 0
	match stream.format:
		AudioStreamWAV.FORMAT_8_BITS:
			bytes_per_sample = 1
		AudioStreamWAV.FORMAT_16_BITS:
			bytes_per_sample = 2
		_:
			# Compressed WAV formats are not reversed in this helper.
			return 0

	var channels := 2 if stream.stereo else 1
	return bytes_per_sample * channels


func _pick_pitch(pitch_randomizer: Array) -> float:
	if pitch_randomizer.size() < 2:
		return 1.0
	return randf_range(float(pitch_randomizer[0]), float(pitch_randomizer[1]))

func play_music(path:String, volume: float = 0.0):
	bgm.stream = load(path)
	bgm.volume_db =volume
	bgm.play()

func stop_music():
	bgm.stop()
