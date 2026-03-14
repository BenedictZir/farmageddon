class_name SelectBoxAnimations

## Builds animations for SelectBox corners programmatically.
## Extracted from select_box.gd for cleaner separation.

const TILE_SIZE := 16
const REST_INSET := 2.0
const PULSE_AMOUNT := 2.0

static var DIRECTIONS: Array[Vector2] = [
	Vector2(-1, 1),   # BL
	Vector2(1, 1),    # BR
	Vector2(1, -1),   # TR
	Vector2(-1, -1),  # TL
]


static func build(anim_players: Array[AnimationPlayer], item_size: Vector2i) -> void:
	var half_w := (item_size.x * TILE_SIZE) / 2.0 - 1.0
	var half_h := (item_size.y * TILE_SIZE) / 2.0 - 1.0

	var edges: Array[Vector2] = [
		Vector2(-half_w, half_h),   # BL
		Vector2(half_w, half_h),    # BR
		Vector2(half_w, -half_h),   # TR
		Vector2(-half_w, -half_h),  # TL
	]

	for i in range(4):
		var ap := anim_players[i]
		var lib: AnimationLibrary = ap.get_animation_library(&"")
		var edge := edges[i]
		var dir := DIRECTIONS[i]
		var rest := edge + dir * (-REST_INSET)

		_build_reset(lib, rest)
		_build_selecting(lib, edge, dir)
		_build_placing(lib, edge)


static func _build_reset(lib: AnimationLibrary, rest: Vector2) -> void:
	var anim := Animation.new()
	anim.length = 0.001
	var t0 := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t0, ".:position")
	anim.track_insert_key(t0, 0.0, rest)
	var t1 := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t1, ".:modulate")
	anim.track_insert_key(t1, 0.0, Color(1, 1, 1, 1))
	lib.remove_animation(&"RESET")
	lib.add_animation(&"RESET", anim)


static func _build_selecting(lib: AnimationLibrary, edge: Vector2, dir: Vector2) -> void:
	var anim := Animation.new()
	anim.length = 0.4
	anim.loop_mode = Animation.LOOP_PINGPONG
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, ".:position")
	anim.value_track_set_update_mode(t, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(t, 0.0, edge)
	anim.track_insert_key(t, 0.1, edge + dir * 1.0)
	anim.track_insert_key(t, 0.2, edge + dir * PULSE_AMOUNT)
	anim.track_insert_key(t, 0.3, edge + dir * 1.0)
	anim.track_insert_key(t, 0.4, edge)
	lib.remove_animation(&"selecting")
	lib.add_animation(&"selecting", anim)


static func _build_placing(lib: AnimationLibrary, edge: Vector2) -> void:
	var anim := Animation.new()
	anim.length = 0.3
	var pt := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(pt, ".:position")
	anim.track_insert_key(pt, 0.0, edge)
	anim.track_insert_key(pt, 0.1, edge)
	anim.track_insert_key(pt, 0.3, Vector2.ZERO)
	var mt := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(mt, ".:modulate")
	anim.value_track_set_update_mode(mt, Animation.UPDATE_DISCRETE)
	anim.track_insert_key(mt, 0.0, Color(4, 4, 4, 1))
	anim.track_insert_key(mt, 0.05, Color(6, 6, 6, 1))
	anim.track_insert_key(mt, 0.1, Color(1, 1, 1, 1))
	anim.track_insert_key(mt, 0.2, Color(1, 1, 1, 0.5))
	anim.track_insert_key(mt, 0.3, Color(1, 1, 1, 0))
	lib.remove_animation(&"placing")
	lib.add_animation(&"placing", anim)
