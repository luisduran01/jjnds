extends SceneTree

const MODEL_PATH := "res://boxing/characters/boxer_model.tscn"
const TARGET_SKELETON := "boxer_rigged/Boxer/Skeleton3D"

const CLIPS := {
	"jab": "boxing_jab",
	"cross": "boxing_cross",

	"body_jab": "boxing_jab",
	"body_cross": "boxing_cross",

	"left_hook": "boxing_left_hook",
	"right_hook": "boxing_right_hook",
	"body_hook": "boxing_left_hook",

	"left_uppercut": "boxing_uppercut",
	"right_uppercut": "boxing_uppercut",

	"block_high": "boxing_left_block",
	"block_body": "boxing_left_block",
}


# ============================================================
# BUSCAR ANIMATION PLAYER
# ============================================================

func find_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node

	for child in node.get_children():
		var player := find_player(child)

		if player:
			return player

	return null


# ============================================================
# BUSCAR SKELETON
# ============================================================

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var skeleton := find_skeleton(child)

		if skeleton:
			return skeleton

	return null


# ============================================================
# RETARGET DE LA ANIMACIÓN
# ============================================================

# Target rig has no clavicles/UpperChest and uses different limb names.
const SOURCE_BONES := {
	"Chest": "UpperChest",
	"LeftForeArm": "LeftLowerArm", "RightForeArm": "RightLowerArm",
	"LeftThigh": "LeftUpperLeg", "RightThigh": "RightUpperLeg",
	"LeftShin": "LeftLowerLeg", "RightShin": "RightLowerLeg",
}

func retarget_action(
	source: Animation,
	source_skeleton: Skeleton3D,
	target_skeleton: Skeleton3D,
	mirror: bool = false
) -> Animation:
	var clip := Animation.new()
	clip.length = source.length
	clip.loop_mode = Animation.LOOP_NONE
	var source_ids: Array[int] = []
	var tracks: Array[int] = []
	for bone in target_skeleton.get_bone_count():
		var name := String(target_skeleton.get_bone_name(bone))
		var source_name: String = SOURCE_BONES.get(name, name)
		if mirror:
			if source_name.begins_with("Left"):
				source_name = source_name.replace("Left", "Right")
			elif source_name.begins_with("Right"):
				source_name = source_name.replace("Right", "Left")
		var source_id := source_skeleton.find_bone(source_name)
		if source_id < 0:
			push_error("Missing retarget bone: " + source_name)
			return null
		source_ids.append(source_id)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("%s:%s" % [TARGET_SKELETON, name]))
		tracks.append(track)
	# Sample the already-imported Godot pose, including every intermediate
	# parent. Pose rotations in Godot 4 INCLUDE rest; they are not rest deltas.
	# Bake global rest-relative motion back into the target's local hierarchy.
	# Position/scale are deliberately not transferred: retain target lengths
	# and leave root translation under CharacterBody3D control.
	var samples := maxi(1, ceili(source.length * 60.0))
	var reflection := Basis.from_scale(Vector3(-1, 1, 1))
	for sample in range(samples + 1):
		var time := source.length * float(sample) / samples
		source_skeleton.reset_bone_poses()
		for track in source.get_track_count():
			if source.track_get_type(track) != Animation.TYPE_ROTATION_3D:
				continue
			var bone := source_skeleton.find_bone(String(source.track_get_path(track).get_concatenated_subnames()))
			if bone >= 0:
				source_skeleton.set_bone_pose_rotation(bone, source.rotation_track_interpolate(track, time))
		source_skeleton.force_update_all_bone_transforms()
		var global_rotations: Array[Basis] = []
		for bone in target_skeleton.get_bone_count():
			var source_id := source_ids[bone]
			var motion := source_skeleton.get_bone_global_pose(source_id).basis.orthonormalized() * source_skeleton.get_bone_global_rest(source_id).basis.orthonormalized().inverse()
			if mirror:
				motion = reflection * motion * reflection
			var desired := motion * target_skeleton.get_bone_global_rest(bone).basis.orthonormalized()
			global_rotations.append(desired)
			var parent := target_skeleton.get_bone_parent(bone)
			var local := desired if parent < 0 else global_rotations[parent].inverse() * desired
			clip.rotation_track_insert_key(tracks[bone], time, local.get_rotation_quaternion().normalized())
	return clip


# ============================================================
# INICIALIZAR
# ============================================================

func _initialize() -> void:
	call_deferred("import_actions")


# ============================================================
# IMPORTAR GOLPES
# ============================================================

func import_actions() -> void:

	print("")
	print("========================================")
	print(" IMPORTANDO ANIMACIONES DE BOXEO")
	print("========================================")
	print("")


	# --------------------------------------------------------
	# CARGAR MODELO DEL BOXEADOR
	# --------------------------------------------------------

	var source_scene := load(MODEL_PATH) as PackedScene

	if source_scene == null:
		push_error(
			"No se pudo cargar: %s" % MODEL_PATH
		)

		quit(1)
		return


	var model := source_scene.instantiate()


	# --------------------------------------------------------
	# OBTENER ANIMATION PLAYER
	# --------------------------------------------------------

	var target_player := model.get_node_or_null(
		"AnimationPlayer"
	) as AnimationPlayer


	if target_player == null:
		push_error(
			"No se encontró AnimationPlayer en boxer_model."
		)

		model.queue_free()

		quit(1)
		return


	# --------------------------------------------------------
	# OBTENER SKELETON
	# --------------------------------------------------------

	var target_skeleton := model.get_node_or_null(
		TARGET_SKELETON
	) as Skeleton3D


	if target_skeleton == null:
		push_error(
			"No se encontró el Skeleton objetivo: %s"
			% TARGET_SKELETON
		)

		model.queue_free()

		quit(1)
		return


	# --------------------------------------------------------
	# ANIMATION LIBRARY
	# --------------------------------------------------------

	var library := target_player.get_animation_library("")


	if library == null:
		library = AnimationLibrary.new()

		target_player.add_animation_library(
			"",
			library
		)


	# ========================================================
	# IMPORTAR CADA ACCIÓN
	# ========================================================

	for action_name in CLIPS:

		var file_name: String = CLIPS[action_name]


		var source_scene_path := (
			"res://boxing/characters/animations/%s.fbx"
			% file_name
		)


		print(
			"Importando ",
			action_name,
			" <- ",
			source_scene_path
		)


		# ----------------------------------------------------
		# CARGAR FBX
		# ----------------------------------------------------

		var imported_scene := load(
			source_scene_path
		) as PackedScene


		if imported_scene == null:

			push_error(
				"No se pudo cargar: %s"
				% source_scene_path
			)

			model.queue_free()

			quit(1)
			return


		var imported := imported_scene.instantiate()
		root.add_child(imported)


		# ----------------------------------------------------
		# BUSCAR ANIMATION PLAYER
		# ----------------------------------------------------

		var source_player := find_player(imported)


		if source_player == null:

			push_error(
				"AnimationPlayer no encontrado en %s"
				% source_scene_path
			)

			imported.queue_free()
			model.queue_free()

			quit(1)
			return


		# ----------------------------------------------------
		# BUSCAR SKELETON
		# ----------------------------------------------------

		var source_skeleton := find_skeleton(imported)


		if source_skeleton == null:

			push_error(
				"Skeleton3D no encontrado en %s"
				% source_scene_path
			)

			imported.queue_free()
			model.queue_free()

			quit(1)
			return


		# ----------------------------------------------------
		# OBTENER ANIMACIÓN MIXAMO
		# ----------------------------------------------------

		var source := source_player.get_animation(
			"mixamo_com"
		)


		if source == null:

			push_error(
				"Missing Mixamo action in %s"
				% source_scene_path
			)

			imported.queue_free()
			model.queue_free()

			quit(1)
			return


		# ----------------------------------------------------
		# CREAR ANIMACIÓN PARA BOXER
		# ----------------------------------------------------

		var retargeted := retarget_action(
			source,
			source_skeleton,
			target_skeleton,
			action_name == "right_uppercut"
		)


		if retargeted == null:
			imported.queue_free()
			model.queue_free()
			quit(1)
			return

		# ----------------------------------------------------
		# REEMPLAZAR ANIMACIÓN ANTIGUA
		# ----------------------------------------------------

		if library.has_animation(action_name):

			library.remove_animation(
				action_name
			)


		library.add_animation(
			action_name,
			retargeted
		)


		print(
			"   OK -> ",
			action_name
		)


		imported.queue_free()


	# ========================================================
	# GUARDAR BOXER_MODEL
	# ========================================================

	# Keep locomotion on the legs while retaining punch hip/torso rotation.
	var tree := model.get_node("AnimationTree") as AnimationTree
	var upper_body := tree.tree_root.get_node("UpperBody") as AnimationNodeBlend2
	upper_body.set_filter_path(NodePath(TARGET_SKELETON + ":Hips"), true)
	var packed := PackedScene.new()


	var pack_error := packed.pack(model)


	if pack_error != OK:

		push_error(
			"Unable to pack boxer model: %s"
			% pack_error
		)

		model.queue_free()

		quit(1)
		return


	var save_error := ResourceSaver.save(
		packed,
		MODEL_PATH
	)


	print("")
	print("========================================")
	print(" IMPORTACIÓN FINALIZADA")
	print(" Resultado: ", save_error)
	print("========================================")
	print("")


	model.queue_free()

	quit(save_error)
