extends SceneTree

func find_first(node: Node, type_name: String) -> Node:
	if node.is_class(type_name): return node
	for child in node.get_children():
		var found=find_first(child,type_name)
		if found: return found
	return null

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	var target_scene=load("res://boxing/characters/boxer_model.tscn") as PackedScene
	var target=target_scene.instantiate()
	var target_player=target.get_node("AnimationPlayer") as AnimationPlayer
	var target_forward=target_player.get_animation("forward")
	print("TARGET first_track=",target_forward.track_get_path(0))
	target.queue_free()
	for clip in ["boxing_forward", "boxing_backward", "boxing_left", "boxing_right"]:
		var scene=load("res://boxing/characters/animations/%s.fbx" % clip) as PackedScene
		var instance=scene.instantiate()
		var player=find_first(instance,"AnimationPlayer") as AnimationPlayer
		print("CLIP ",clip," player=",player != null)
		if player:
			print(" libraries=",player.get_animation_library_list())
			for library_name in player.get_animation_library_list():
				var library=player.get_animation_library(library_name)
				for animation_name in library.get_animation_list():
					var animation=library.get_animation(animation_name)
					print(" animation=",animation_name," tracks=",animation.get_track_count())
					if animation.get_track_count()>0:
						print(" first_track=",animation.track_get_path(0)," type=",animation.track_get_type(0)," keys=",animation.track_get_key_count(0))
						if animation.track_get_key_count(0)>1: print(" root_from=",animation.track_get_key_value(0,0)," root_to=",animation.track_get_key_value(0,animation.track_get_key_count(0)-1))
		instance.queue_free()
	quit()
