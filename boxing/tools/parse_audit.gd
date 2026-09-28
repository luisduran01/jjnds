extends SceneTree

const PATHS := [
	"res://addons/godot_ai/plugin.gd",
	"res://boxing/characters/procedural_rig.gd",
	"res://boxing/tests/debug_hook.gd",
	"res://boxing/tests/fight_sim.gd",
	"res://boxing/tests/pose_test.gd",
	"res://boxing/tools/import_locomotion_animations.gd",
	"res://boxing/tools/import_punch_animations.gd",
	"res://boxing/characters/fighter.gd",
]

func _initialize() -> void:
	for path in PATHS:
		var script=load(path)
		print("PARSE ",path," => ",script != null)
	quit()
