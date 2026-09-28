extends SceneTree

func find_rig(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var found=find_rig(child)
		if found: return found
	return null

func own(node: Node,scene: Node) -> void:
	for child in node.get_children():
		child.owner=scene
		own(child,scene)

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var model=Node3D.new()
	model.name="Model"
	root.add_child(model)
	var imported=load("res://boxing/characters/boxer_rigged.glb").instantiate()
	model.add_child(imported)
	var skeleton=find_rig(imported)
	var animations=load("res://boxing/characters/animation_factory.gd").build(model,skeleton)
	ResourceSaver.save(animations.player.get_animation_library(""),"res://boxing/characters/boxing_animations.tres")
	own(model,model)
	var packed=PackedScene.new()
	var error=packed.pack(model)
	if error==OK: error=ResourceSaver.save(packed,"res://boxing/characters/boxer_model.tscn")
	print("Editable model and animation library saved: ",error)
	model.queue_free()
	await process_frame
	quit(error)
