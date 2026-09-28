@tool
extends EditorScript

func _run():
	var anim_dir = "res://characters/3d/animations/"
	var dir = DirAccess.open(anim_dir)
	if not dir:
		print("Error: Could not open directory " + anim_dir)
		return
		
	var lib = AnimationLibrary.new()
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		if file_name.ends_with(".glb"):
			var path = anim_dir + file_name
			var packed_scene = ResourceLoader.load(path) as PackedScene
			if packed_scene:
				var instance = packed_scene.instantiate()
				var anim_player = instance.get_node_or_null("AnimationPlayer")
				if anim_player:
					for anim_name in anim_player.get_animation_list():
						var anim = anim_player.get_animation(anim_name).duplicate()
						var final_name = file_name.replace(".glb", "")
						
						# Save animation into the library using the filename
						if not lib.has_animation(final_name):
							lib.add_animation(final_name, anim)
							print("✅ Extracted: " + final_name)
				instance.free()
		file_name = dir.get_next()
		
	var save_path = "res://characters/3d/animations/boxer_library.res"
	ResourceSaver.save(lib, save_path)
	EditorInterface.get_resource_filesystem().scan()
	print("=======================================")
	print("🚀 Éxito! Librería guardada en: " + save_path)
	print("=======================================")
