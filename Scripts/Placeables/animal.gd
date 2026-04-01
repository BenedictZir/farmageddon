extends Placeable

## A placed animal on an animal tile. Handles feeding, production timer, and product readiness.

enum AnimalState { HUNGRY, PROCESSING, READY }

@onready var sprite: Sprite2D = $Sprite2D
@onready var status_sprite: Sprite2D = $StatusSprite
@onready var progress_bar: TextureProgressBar = $ProgressBar

var animal_data: AnimalData
var state: AnimalState = AnimalState.HUNGRY
var _production_timer := 0.0
var _anim_timer := 0.0
var _ready_bounce_tween: Tween
var _status_base_pos := Vector2.ZERO


func setup(data: AnimalData) -> void:
	animal_data = data
	state = AnimalState.HUNGRY
	_production_timer = 0.0
	_anim_timer = 0.0
	_stop_ready_bounce()
	
	if animal_data.sprite_sheet:
		sprite.texture = animal_data.sprite_sheet
		sprite.hframes = animal_data.hframes
		sprite.vframes = animal_data.vframes
		sprite.frame = 0
	if status_sprite:
		_status_base_pos = status_sprite.position
		
	_update_visuals()


func _process(delta: float) -> void:
	if animal_data and animal_data.sprite_sheet and (animal_data.hframes * animal_data.vframes > 1) and animal_data.animation_speed > 0:
		_anim_timer += delta
		var spf = 1.0 / animal_data.animation_speed
		if _anim_timer >= spf:
			_anim_timer -= spf
			sprite.frame = (sprite.frame + 1) % (animal_data.hframes * animal_data.vframes)
			
	if state == AnimalState.PROCESSING:
		_production_timer += delta
		if progress_bar:
			progress_bar.value = get_production_progress() * 100.0
		if _production_timer >= animal_data.production_time:
			_production_timer = animal_data.production_time
			state = AnimalState.READY
			_update_visuals()


func feed() -> void:
	if state != AnimalState.HUNGRY:
		return
	state = AnimalState.PROCESSING
	_production_timer = 0.0
	_update_visuals()


func harvest_product() -> AnimalProductData:
	if state != AnimalState.READY:
		return null
	var product := animal_data.product_data
	state = AnimalState.HUNGRY
	_production_timer = 0.0
	_update_visuals()
	return product


func is_hungry() -> bool:
	return state == AnimalState.HUNGRY


func is_product_ready() -> bool:
	return state == AnimalState.READY


func get_production_progress() -> float:
	if state != AnimalState.PROCESSING or animal_data.production_time <= 0:
		return 0.0
	return _production_timer / animal_data.production_time


func _update_visuals() -> void:
	if not status_sprite:
		return
	match state:
		AnimalState.HUNGRY:
			_stop_ready_bounce()
			# Show hunger indicator
			status_sprite.visible = true
			if animal_data and animal_data.product_data and animal_data.product_data.icon:
				status_sprite.texture = animal_data.product_data.icon
			status_sprite.modulate = Color(1, 1, 1, 0.0)
			if progress_bar: progress_bar.visible = false
		AnimalState.PROCESSING:
			_stop_ready_bounce()
			# Show processing (progress bar)
			status_sprite.visible = false
			status_sprite.modulate = Color(1, 1, 1, 0.0)
			if progress_bar: progress_bar.visible = true
		AnimalState.READY:
			_stop_ready_bounce()
			# Show product ready (bright icon + bounce)
			status_sprite.visible = true
			if animal_data and animal_data.product_data and animal_data.product_data.icon:
				status_sprite.texture = animal_data.product_data.icon
			status_sprite.modulate = Color.WHITE
			if progress_bar: progress_bar.visible = false
			_play_ready_bounce()


func _play_ready_bounce() -> void:
	if not status_sprite:
		return
	if _ready_bounce_tween and _ready_bounce_tween.is_running():
		return

	status_sprite.position = _status_base_pos + Vector2(0.0, -10.0)
	_ready_bounce_tween = create_tween().set_loops()
	_ready_bounce_tween.tween_property(status_sprite, "position:y", _status_base_pos.y - 14.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_ready_bounce_tween.tween_property(status_sprite, "position:y", _status_base_pos.y - 10.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_ready_bounce() -> void:
	if _ready_bounce_tween and _ready_bounce_tween.is_running():
		_ready_bounce_tween.kill()
	_ready_bounce_tween = null
	if status_sprite:
		status_sprite.position = _status_base_pos


func _exit_tree() -> void:
	_stop_ready_bounce()
