extends SceneTree

func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var player := find_player(child)
		if player: return player
	return null

func _initialize() -> void:
	call_deferred("inspect")

func inspect() -> void:
	for clip in ["boxing_jab", "boxing_jab_cross", "boxing_body_jab_cross", "boxing_punching"]:
		var scene := load("res://characters/3d/animations/%s.fbx" % clip) as PackedScene
		var instance := scene.instantiate()
		var player := find_player(instance)
		print("CLIP ",clip)
		for animation_name in player.get_animation_list():
			var animation := player.get_animation(animation_name)
			print(" name=",animation_name," length=",animation.length," tracks=",animation.get_track_count())
		instance.queue_free()
	quit()
