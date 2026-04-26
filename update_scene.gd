@tool
extends SceneTree

func _init():
	var scene = load("res://Scenes/Level/level_2.tscn") as PackedScene
	var root = scene.instantiate()
	var tc = root.get_node("TutorialController")
	if tc:
		tc.tutorial_data = load("res://Resources/Tutorials/level_2_tutorial.tres")
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, "res://Scenes/Level/level_2.tscn")
		print("Successfully updated level_2.tscn")
	else:
		print("TutorialController not found")
	
	quit()
