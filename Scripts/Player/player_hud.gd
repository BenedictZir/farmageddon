extends CanvasLayer


@onready var health_bar: TextureProgressBar = $PlayerHP
@onready var energy_bar: TextureProgressBar = $PlayerEnergy

@export var tween_speed := 0.3

var _health_tween: Tween
var _energy_tween: Tween


func _ready() -> void:
	health_bar.value = 100.0
	energy_bar.value = 100.0


func update_bars(health_ratio: float, energy_ratio: float) -> void:
	_smooth_set(health_bar, health_ratio * 100.0, "_health_tween")
	_smooth_set(energy_bar, energy_ratio * 100.0, "_energy_tween")


func _smooth_set(bar: TextureProgressBar, target: float, tween_var: String) -> void:
	var existing: Tween = get(tween_var)
	if existing and existing.is_running():
		existing.kill()

	if absf(bar.value - target) < 0.5:
		bar.value = target
		return

	var tw := create_tween()
	tw.tween_property(bar, "value", target, tween_speed)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_CUBIC)
	set(tween_var, tw)
