extends CanvasLayer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dissolve_rect: ColorRect = $dissolve_rect
func _ready():
	pass

func change_scene(target, color = "000000") -> void:
	dissolve_rect.color = color
	animation_player.play("dissolve")
	await animation_player.animation_finished
	get_tree().change_scene_to_file(target)
	animation_player.play_backwards("dissolve")

func transition(color = "000000") -> void:
	dissolve_rect.color = color
	animation_player.play("dissolve_slow")
	await animation_player.animation_finished
	animation_player.play_backwards("dissolve_slow")
