extends Node
class_name TutorialController

## Generic tutorial controller — attach to any level.
## Assign a TutorialSequence resource + spotlight/dialog paths in Inspector.
## Handles custom actions like "show_timer", "start_spawner", etc.
##
## REUSABLE: Copy this script + TutorialRunner + TutorialStep + TutorialSequence
## to any Godot 4 project. Override _on_custom_action() for game-specific actions.

@export var tutorial_data: TutorialSequence

@export_group("Node References")
@export var spotlight_path: NodePath
@export var dialog_box_path: NodePath

@export_group("Game Node References (for custom actions)")
@export var timer_label_path: NodePath
@export var enemy_spawner_path: NodePath
@export var forage_spawner_path: NodePath = NodePath("../ForageSpawner")

@export_group("Settings")
@export var auto_start := true
@export var start_delay := 0.5
@export var hide_timer_initially := false
@export var tutorial_loan_amount := 30

var _runner: TutorialRunner
var _tutorial_loan_given := false
var _timer_started_during_tutorial := false
var _gold_revealed_during_tutorial := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not tutorial_data:
		return

	if _is_done(tutorial_data.save_key):
		queue_free()
		return

	GameManager.tutorial_active = true
	GameManager.pause_level_timer()
	_tutorial_loan_given = false
	_timer_started_during_tutorial = false
	_gold_revealed_during_tutorial = false

	var gold_lbl := get_node_or_null("../UI/GoldLabel") as GoldCounterLabel
	if gold_lbl:
		gold_lbl.lock_display()

	if hide_timer_initially:
		var timer_lbl := get_node_or_null(timer_label_path) as Control
		if timer_lbl:
			timer_lbl.visible = false

	if auto_start:
		await get_tree().create_timer(start_delay).timeout
		start()


func start() -> void:
	if not tutorial_data:
		return

	var spot := get_node_or_null(spotlight_path) as TutorialSpotlight
	var dialog := get_node_or_null(dialog_box_path) as TutorialDialogBox

	if not spot or not dialog:
		push_warning("[TutorialController] Spotlight or DialogBox not found!")
		return

	_runner = TutorialRunner.new()
	add_child(_runner)
	_runner.tutorial_completed.connect(_on_completed)
	_runner.custom_action_requested.connect(_on_custom_action)
	_runner.start(tutorial_data, spot, dialog, get_tree().current_scene)


## Override this in subclasses or extend with match cases for your game.
func _on_custom_action(action_name: String) -> void:
	match action_name:
		"show_timer":
			var timer_lbl := get_node_or_null(timer_label_path) as Control
			if timer_lbl:
				timer_lbl.visible = true
			if not _timer_started_during_tutorial:
				GameManager.start_level_timer_from_full()
				_timer_started_during_tutorial = true
			else:
				GameManager.resume_level_timer()
		"hide_timer":
			var timer_lbl := get_node_or_null(timer_label_path) as Control
			if timer_lbl:
				timer_lbl.visible = false
		"start_spawner":
			var spawner := get_node_or_null(enemy_spawner_path)
			if spawner:
				if spawner.has_method("start_from_tutorial"):
					spawner.start_from_tutorial()
				else:
					spawner.set_process(true)
		"pause_spawner":
			var spawner := get_node_or_null(enemy_spawner_path)
			if spawner:
				if spawner.has_method("pause_from_tutorial"):
					spawner.pause_from_tutorial()
				else:
					spawner.set_process(false)
		"grant_tutorial_loan":
			if _tutorial_loan_given:
				return
			_tutorial_loan_given = true
			CurrencyManager.add_gold(maxi(0, tutorial_loan_amount))
			var gold_lbl := get_node_or_null("../UI/GoldLabel") as GoldCounterLabel
			if gold_lbl:
				gold_lbl.unlock_display(true)
				_gold_revealed_during_tutorial = true
		_:
			push_warning("[TutorialController] Unknown custom action: %s" % action_name)


func _on_completed() -> void:
	_save_done(tutorial_data.save_key)
	if _timer_started_during_tutorial:
		GameManager.resume_level_timer()
	else:
		GameManager.start_level_timer_from_full()
	
	var forage_spawner := get_node_or_null(forage_spawner_path)
	if forage_spawner:
		if forage_spawner.has_method("start_from_tutorial"):
			forage_spawner.start_from_tutorial()
		else:
			forage_spawner.set_process(true)

	if not _gold_revealed_during_tutorial:
		var gold_lbl := get_node_or_null("../UI/GoldLabel") as GoldCounterLabel
		if gold_lbl:
			gold_lbl.unlock_display(true)

	var timer_lbl := get_node_or_null(timer_label_path) as Control
	if timer_lbl:
		timer_lbl.visible = true

	queue_free()


# ── Save/Load ────────────────────────────────────────────────────────

func _is_done(key: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load("user://progress.cfg") == OK:
		return cfg.get_value("tutorials", key, false)
	return false


func _save_done(key: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://progress.cfg")
	cfg.set_value("tutorials", key, true)
	cfg.save("user://progress.cfg")
