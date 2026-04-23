extends Resource
class_name TutorialStep

## A single tutorial step — configurable entirely from the Inspector.

enum StepType { DIALOG, ACTION }
enum SpotlightShape { NONE, RECTANGLE, CIRCLE }

## What type of step this is
@export var type: StepType = StepType.DIALOG

## Dialog lines shown sequentially (click to advance)
@export var lines: Array[String] = []

## ── Spotlight Settings ──────────────────────────────────────────────
@export_group("Spotlight")

## Shape of the spotlight hole
@export var spotlight_shape: SpotlightShape = SpotlightShape.NONE

## Screen position of spotlight center (pixels). Ignored if spotlight_node is set.
@export var spotlight_position: Vector2 = Vector2.ZERO

## Size of the spotlight area (pixels)
@export var spotlight_size: Vector2 = Vector2(100, 100)

## Follow a node in the scene (path relative to level root, e.g. "Player", "UI/ShopUI")
@export var spotlight_node_path: String = ""

## Optional second node path to include in the same spotlight area.
## Useful when one step needs to highlight two UI items at once.
@export var spotlight_secondary_node_path: String = ""

## Extra padding around a node target
@export var spotlight_padding: Vector2 = Vector2(20, 20)

## ── Game Flow ───────────────────────────────────────────────────────
@export_group("Game Flow")

## Whether to pause the game during this step
@export var pause_game: bool = true

## Hold duration — wait this many seconds of active input, then auto-advance.
## 0 = no hold (normal click-to-advance or signal-wait).
@export var hold_duration: float = 0.0

## Input actions that must be pressed for hold timer to count down.
## If empty, hold timer counts passively (wall-clock).
## Example: ["move_up", "move_down", "move_left", "move_right"] for WASD.
@export var hold_actions: Array[String] = []

## Inputs to unlock when this step starts (e.g. ["shop_toggle", "interact"])
@export var unlock_inputs: Array[String] = []

## Custom actions to run when step starts (e.g. ["show_timer", "start_timer"])
@export var on_start_actions: Array[String] = []

## ── Key Prompt ──────────────────────────────────────────────────────
@export_group("Key Prompt")

## Key name to display as animated prompt (e.g. "E", "TAB", "SHIFT", "J").
## Use separators like + , / or | for multiple keys (e.g. "J+K", "Q,E").
## Leave empty for no key prompt. Uses sprites from Assets/Key/.
@export var key_prompt: String = ""

## ── Visual Effects ──────────────────────────────────────────────────
@export_group("Visual Effects")

## Shake the camera when this step's dialog first appears.
@export var camera_shake: bool = false

## ── Action Settings (for ACTION type) ───────────────────────────────
@export_group("Action")

## Signal name to wait for (e.g. "gold_changed")
@export var action_signal_name: String = ""

## Autoload name that emits the signal (e.g. "CurrencyManager")
@export var action_source_autoload: String = ""

## Node path relative to level root that emits the signal
@export var action_source_node_path: String = ""

## Input action name to wait for (e.g. "shop_toggle", "attack")
## If set, waits for this input press instead of a signal.
@export var action_input_name: String = ""

## If true, hides dialog/spotlight while waiting for the signal.
## Dialog shows AFTER the signal fires (e.g. wait for enemy, then explain).
## If false, dialog shows immediately while waiting (e.g. "Buy carrot!").
@export var wait_silent: bool = false

## Delay in seconds after signal fires before showing dialog.
## Only used with wait_silent=true. E.g. 3.0 to let enemy walk into view.
@export var signal_delay: float = 0.0

## If true, ACTION signal callbacks will try to spotlight the first Node2D signal argument.
## Example: enemy spawner emits spawned enemy node, spotlight follows that enemy.
@export var spotlight_signal_target: bool = false
