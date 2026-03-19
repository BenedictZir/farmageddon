extends CanvasLayer
class_name UpgradeShop

## UI interface for buying Health, Speed, and Interaction upgrades.

@onready var health_button: Button = $Panel/VBox/HealthRow/BuyButton
@onready var health_cost_label: Label = $Panel/VBox/HealthRow/CostLabel
@onready var health_desc: Label = $Panel/VBox/HealthRow/DescLabel

@onready var speed_button: Button = $Panel/VBox/SpeedRow/BuyButton
@onready var speed_cost_label: Label = $Panel/VBox/SpeedRow/CostLabel
@onready var speed_desc: Label = $Panel/VBox/SpeedRow/DescLabel

@onready var interact_button: Button = $Panel/VBox/InteractRow/BuyButton
@onready var interact_cost_label: Label = $Panel/VBox/InteractRow/CostLabel
@onready var interact_desc: Label = $Panel/VBox/InteractRow/DescLabel
@onready var close_button: Button = $Panel/CloseButton


func _ready() -> void:
	visible = false
	health_button.pressed.connect(_on_health_pressed)
	speed_button.pressed.connect(_on_speed_pressed)
	interact_button.pressed.connect(_on_interact_pressed)
	close_button.pressed.connect(close)
	
	UpgradeManager.upgrades_changed.connect(_update_ui)
	CurrencyManager.gold_changed.connect(func(_new_balance): _update_ui())
	_update_ui()


func _update_ui() -> void:
	# Update costs
	health_cost_label.text = str(UpgradeManager.get_health_price()) + "g"
	speed_cost_label.text = str(UpgradeManager.get_speed_price()) + "g"
	interact_cost_label.text = str(UpgradeManager.get_interact_price()) + "g"
	
	# Update descriptions (show current level)
	health_desc.text = "+Max Health & Heal (Lv " + str(UpgradeManager.health_level) + ")"
	speed_desc.text = "+Movement Speed (Lv " + str(UpgradeManager.speed_level) + ")"
	interact_desc.text = "+Farming Speed (Lv " + str(UpgradeManager.interact_level) + ")"
	
	# Disable buttons if not enough gold
	var g = CurrencyManager.gold
	health_button.disabled = g < UpgradeManager.get_health_price()
	speed_button.disabled = g < UpgradeManager.get_speed_price()
	interact_button.disabled = g < UpgradeManager.get_interact_price()


func _on_health_pressed() -> void:
	UpgradeManager.buy_health()


func _on_speed_pressed() -> void:
	UpgradeManager.buy_speed()


func _on_interact_pressed() -> void:
	UpgradeManager.buy_interact()


func open() -> void:
	_update_ui()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		close()
		get_viewport().set_input_as_handled()
