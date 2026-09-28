extends SceneTree

const MODEL_PATH := "res://boxing/characters/boxer_model.tscn"
const BASE_ANIMATIONS_PATH := "res://boxing/characters/boxing_animations.tres"
const TARGET_SKELETON := "boxer_rigged/Boxer/Skeleton3D"
const PunchRetarget = preload("res://boxing/tools/import_punch_animations.gd")
const UPPER_BODY := ["Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftForeArm", "LeftHand", "RightUpperArm", "RightForeArm", "RightHand"]
const CLIPS := {
	"boxing_idle": "boxing_idle",
	"forward": "boxing_forward",
	"backward": "boxing_backward",
	"left": "boxing_left",
	"right": "boxing_right",
}

func find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var player := find_animation_player(child)
		if player:
			return player
	return null

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var skeleton := find_skeleton(child)
		if skeleton:
			return skeleton
	return null

func retarget_locomotion(source: Animation,source_skeleton: Skeleton3D,target_skeleton: Skeleton3D) -> Animation:
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_LINEAR
	for index in range(clip.get_track_count()-1, -1, -1):
		var source_path := clip.track_get_path(index)
		var bone := String(source_path.get_concatenated_subnames())
		# Imported Mixamo clips move the hips through world space. The fighter's
		# CharacterBody3D owns translation, so only the skeletal stride is retained.
		if bone == "Hips" and clip.track_get_type(index) == Animation.TYPE_POSITION_3D:
			clip.remove_track(index)
		elif not bone.is_empty():
			clip.track_set_path(index, NodePath("%s:%s" % [TARGET_SKELETON, bone]))
			if clip.track_get_type(index) == Animation.TYPE_ROTATION_3D:
				var source_bone := source_skeleton.find_bone(bone)
				var target_bone := target_skeleton.find_bone(bone)
				if source_bone >= 0 and target_bone >= 0:
					var rest_delta := target_skeleton.get_bone_rest(target_bone).basis.inverse()*source_skeleton.get_bone_rest(source_bone).basis
					var correction := rest_delta.get_rotation_quaternion()
					for key in clip.track_get_key_count(index):
						var rotation: Quaternion = clip.track_get_key_value(index,key)
						clip.track_set_key_value(index,key,correction*rotation)
	# The legacy stride remains unchanged. Its upper-body tracks used different
	# bone names/axes, leaving elbows unanimated when returning from a punch.
	var corrected := PunchRetarget.retarget_action(source, source_skeleton, target_skeleton)
	if corrected == null:
		return null
	for index in range(clip.get_track_count() - 1, -1, -1):
		var bone := String(clip.track_get_path(index).get_concatenated_subnames())
		if bone in UPPER_BODY:
			clip.remove_track(index)
	for index in corrected.get_track_count():
		var bone := String(corrected.track_get_path(index).get_concatenated_subnames())
		if bone in UPPER_BODY:
			corrected.copy_track(index, clip)
	return clip

func _initialize() -> void:
	call_deferred("import_clips")

func import_clips() -> void:
	var source_scene := load(MODEL_PATH) as PackedScene
	var model := source_scene.instantiate()
	var target_player := model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	var target_skeleton := model.get_node_or_null(TARGET_SKELETON) as Skeleton3D
	if target_player == null:
		push_error("boxer_model.tscn has no AnimationPlayer")
		quit(1)
		return
	var library := target_player.get_animation_library("")
	# Keep the legacy `idle` clip for the action state machine. Locomotion uses
	# the downloaded `boxing_idle` clip at its BlendSpace center.
	var base_library := load(BASE_ANIMATIONS_PATH) as AnimationLibrary
	if library.has_animation("idle"):
		library.remove_animation("idle")
	library.add_animation("idle", base_library.get_animation("idle").duplicate(true))
	for target_name in CLIPS:
		var source_path := "res://boxing/characters/animations/%s.fbx" % CLIPS[target_name]
		var imported_scene := load(source_path) as PackedScene
		var imported := imported_scene.instantiate()
		root.add_child(imported)
		var source_player := find_animation_player(imported)
		var source_skeleton := find_skeleton(imported)
		var source := source_player.get_animation("mixamo_com")
		if source == null:
			push_error("Missing Mixamo clip in %s" % source_path)
			quit(1)
			return
		var retargeted := retarget_locomotion(source,source_skeleton,target_skeleton)
		if retargeted == null:
			imported.queue_free()
			model.queue_free()
			quit(1)
			return
		if library.has_animation(target_name):
			library.remove_animation(target_name)
		library.add_animation(target_name, retargeted)
		imported.queue_free()
	var packed := PackedScene.new()
	var pack_error := packed.pack(model)
	if pack_error != OK:
		push_error("Unable to pack boxer model: %s" % pack_error)
		quit(1)
		return
	var save_error := ResourceSaver.save(packed, MODEL_PATH)
	print("Imported boxing_idle/forward/backward/left/right Mixamo locomotion: ", save_error)
	model.queue_free()
	quit(save_error)
