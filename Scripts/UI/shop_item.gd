extends AnimatedButton
class_name ShopItem

## A single item slot in the shop.

@export var item_id: int = 1
@export var item_name: String = "Item Name"
@export var price: int = 10
@export var icon: Texture2D
@export var item_data: Resource  # CropData, or any placeable data
@export var is_goal := false
@export var unlock_level: int = 1
@export var locked_button_modulate := Color(0.5, 0.5, 0.5, 1.0)
@export var affordable_button_modulate := Color.WHITE
@export var unaffordable_button_modulate := Color(0.62, 0.62, 0.62, 1.0)
@export var affordable_price_color := Color(1.0, 0.95, 0.58, 1.0)
@export var unaffordable_price_color := Color(0.95, 0.56, 0.56, 1.0)
@export var affordability_tween_duration := 0.16

@onready var name_label: Label = $NameLabel
@onready var icon_rect: TextureRect = $IconRect
@onready var price_label: Label = $PriceLabel
@onready var number_label: Label = $NumberLabel

var _afford_tween: Tween


func _ready() -> void:
	super()
	
	if is_goal:
		var goal_data = GameManager.get_current_goal_data()
		item_name = goal_data.get("name", "Goal")
		price = goal_data.get("price", 9999)
		icon = goal_data.get("icon", null)
		
	# Apply Locked visual state before initialization so text overriding works
	var is_locked = GameManager.get_current_level_index() < unlock_level
	if is_locked:
		name_label.text = "???"
		price_label.text = "???"
		if icon:
			icon_rect.texture = icon
			icon_rect.modulate = Color(0, 0, 0, 1) # Solid black silhouette
		shrink_to_normal()
		modulate = locked_button_modulate
		price_label.self_modulate = Color.WHITE
		disabled = true
	else:
		name_label.text = item_name
		price_label.text = str(price) + "g"
		if icon:
			icon_rect.texture = icon
			# Goal icons stay as black silhouette (mystery reveal)
			icon_rect.modulate = Color(0, 0, 0, 1) if is_goal else Color.WHITE

		if CurrencyManager.has_signal("gold_changed") and not CurrencyManager.gold_changed.is_connected(_on_gold_changed):
			CurrencyManager.gold_changed.connect(_on_gold_changed)
		_update_affordability()
	number_label.text = str(item_id)

func _on_pressed() -> void:
	var action_name := "shop_" + str(item_id)
	if not GameManager.is_input_unlocked(action_name):
		return

	super()

	# Goal items don't need item_data — just spend gold and celebrate
	if is_goal:
		if not CurrencyManager.spend_gold(price):
			AudioGlobal.start_ui_sfx("res://Assets/SFX/Cancel.wav", [0.97, 1.02], -5)
			return
		_play_goal_animation()
		return

	if not item_data:
		return

	# Helper instant-buy logic
	if item_data.has_method("is_helper") and item_data.is_helper():
		if not CurrencyManager.spend_gold(price):
			AudioGlobal.start_ui_sfx("res://Assets/SFX/Cancel.wav", [0.97, 1.02], -5)
			return
		var helper = item_data.helper_scene.instantiate()
		var extents := GameManager.map_extents
		var spawn_pos := Vector2.ZERO
		
		# Pick a random edge to spawn on
		var edge = randi() % 4
		match edge:
			0: spawn_pos = Vector2(randf_range(-extents.x, extents.x), -extents.y - 20) # Top
			1: spawn_pos = Vector2(randf_range(-extents.x, extents.x), extents.y + 20) # Bottom
			2: spawn_pos = Vector2(-extents.x - 20, randf_range(-extents.y, extents.y)) # Left
			3: spawn_pos = Vector2(extents.x + 20, randf_range(-extents.y, extents.y)) # Right
			
		helper.global_position = spawn_pos
		get_tree().current_scene.add_child(helper)
		
		# If this helper was the goal, play dramatic animation then win
		if is_goal:
			_play_goal_animation()
		return

	# Interception logic — give to ANY farmer whose queue is completely empty
	var farmers = get_tree().get_nodes_in_group("farmer_helpers")
	var available_farmer: FarmerHelper = null
	for f in farmers:
		if f.seed_queue.size() + f.fertilizer_queue.size() == 0:
			available_farmer = f
			break
	
	if available_farmer:
		var type = item_data.get_placeable_type()
		if type == Placeable.Type.CROP:
			if CurrencyManager.spend_gold(price):
				available_farmer.add_seed_to_queue(item_data)
			else:
				AudioGlobal.start_ui_sfx("res://Assets/SFX/Cancel.wav", [0.97, 1.02], -5)
				
			return
		elif type == Placeable.Type.FERTILIZER:
			if CurrencyManager.spend_gold(price):
				available_farmer.add_fertilizer(item_data)
			else:
				AudioGlobal.start_ui_sfx("res://Assets/SFX/Cancel.wav", [0.97, 1.02], -5)
			return

	# Normal behavior (player holds item, must not have full hands)
	var player := PlayerRef.instance
	if not player or player.is_carrying:
		return
	if not CurrencyManager.spend_gold(price):
		AudioGlobal.start_ui_sfx("res://Assets/SFX/Cancel.wav", [0.97, 1.02], -5)
		return
	player.hold_item(item_data)
	if is_goal:
		_play_goal_animation()


func _on_gold_changed(_new_gold: int) -> void:
	_update_affordability()


func _update_affordability() -> void:
	if GameManager.get_current_level_index() < unlock_level:
		return # Let the _ready pass handle keeping it disabled/dark
		
	var can_afford = CurrencyManager.can_afford(price)
	disabled = not can_afford
	var target_button := affordable_button_modulate if can_afford else unaffordable_button_modulate
	var target_price := affordable_price_color if can_afford else unaffordable_price_color
	_animate_affordability(target_button, target_price)

	if not can_afford:
		shrink_to_normal()

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.get_current_level_index() < unlock_level or not CurrencyManager.can_afford(price):
		return
	
	var action_name := "shop_" + str(item_id)
	if Input.is_action_just_pressed(action_name):
		if not GameManager.is_input_unlocked(action_name):
			return
		_press_with_keyboard()

func _press_with_keyboard():
	_on_pressed()
	if _tween:
		await _tween.finished
		shrink_to_normal()


func _animate_affordability(target_button: Color, target_price: Color) -> void:
	if _afford_tween and _afford_tween.is_running():
		_afford_tween.kill()

	_afford_tween = create_tween()
	_afford_tween.tween_property(self, "modulate", target_button, affordability_tween_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if price_label:
		_afford_tween.parallel().tween_property(price_label, "self_modulate", target_price, affordability_tween_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _play_goal_animation() -> void:
	AudioGlobal.stop_music()
	var anim := GoalPurchaseAnimation.new()
	anim.goal_icon = icon
	anim.goal_name = item_name
	anim.start_screen_position = icon_rect.get_global_rect().get_center()
	anim.source_icon_rect = icon_rect  # Pass actual node to reparent
	get_tree().root.add_child(anim)
	AudioGlobal.start_ui_sfx("res://Assets/SFX/level_complete.wav", [0.97, 1.02], -5)
	anim.animation_finished.connect(GameManager.complete_current_level)

func _play_press_sfx():
	pass # dont play press sfx for shop item button because spend gold already have sfx
