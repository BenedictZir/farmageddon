extends Resource
class_name TutorialSequence

## A collection of tutorial steps — assign to any level's TutorialController.
## Create one .tres per level (e.g. level_1_tutorial.tres, level_2_tutorial.tres)

## NPC name shown in the dialog box
@export var npc_name: String = "Chicky"

## Unique key for saving completion (e.g. "level_1", "level_2")
@export var save_key: String = "level_1"

## The ordered list of steps
@export var steps: Array[TutorialStep] = []
