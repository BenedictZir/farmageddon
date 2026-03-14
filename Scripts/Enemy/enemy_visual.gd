extends AnimatedSprite2D
class_name EnemyVisual

## Visual controller for enemies. Manages animation playback and flip.

var _current_anim := ""
var _locked := false  # true during one-shot anims (attack, doing)

signal anim_finished(anim_name: String)
signal jump_finished


func _ready() -> void:
	animation_finished.connect(_on_animation_finished)

func do_jump(duration := 1.0, height := 24.0) -> void:
	var tw = create_tween()
	# Jump up (negative Y)
	tw.tween_property(self, "position:y", -height, duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	# Fall down (back to 0)
	tw.tween_property(self, "position:y", 0.0, duration / 2.0)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	tw.finished.connect(func():
		jump_finished.emit()
	)


func is_locked() -> bool:
	return _locked


func unlock() -> void:
	_locked = false


func play_anim(anim_name: String) -> void:
	if _locked:
		return
	_set_anim(anim_name)


func play_anim_locked(anim_name: String) -> void:
	## Play a one-shot animation that locks movement until finished.
	_locked = true
	_set_anim(anim_name, true)


func update_flip(dir: Vector2) -> void:
	if dir.x != 0:
		flip_h = dir.x < 0


func _set_anim(anim_name: String, force := false) -> void:
	if (force or _current_anim != anim_name) and sprite_frames \
		and sprite_frames.has_animation(anim_name):
		play(anim_name)
		_current_anim = anim_name


func _on_animation_finished() -> void:
	if _locked:
		_locked = false
		anim_finished.emit(_current_anim)
		_current_anim = ""
