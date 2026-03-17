extends Placeable

## A planted crop on a tile. Shows growth phase sprites over time.

@onready var sprite: Sprite2D = $Sprite2D

var crop_data: CropData
var growth_phase := 0
var _growth_timer := 0.0
var _phase_duration := 0.0
var fully_grown := false
var fertilized := false
func setup(data: CropData) -> void:
	crop_data = data
	growth_phase = 0
	fully_grown = false
	# Grow time is split among phases 0 to N-2; last phase = harvest-ready
	var growing_phases = max(data.phase_textures.size() - 1, 1)
	_phase_duration = data.grow_time / growing_phases
	_growth_timer = 0.0
	_update_sprite()


func _process(delta: float) -> void:
	if fully_grown or not crop_data:
		return

	_growth_timer += delta
	if _growth_timer >= _phase_duration:
		_growth_timer -= _phase_duration
		growth_phase += 1
		var last_phase := crop_data.phase_textures.size() - 1
		if growth_phase >= last_phase:
			growth_phase = last_phase
			fully_grown = true
		_update_sprite()


func _update_sprite() -> void:
	if crop_data and crop_data.phase_textures.size() > growth_phase:
		sprite.texture = crop_data.phase_textures[growth_phase]

func fertilize() -> void:
	if fertilized:
		return
	fertilized = true
	_phase_duration *= 0.75 
