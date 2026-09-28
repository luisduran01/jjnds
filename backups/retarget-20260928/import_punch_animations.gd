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

func retarget_action(
	source: Animation,
	source_skeleton: Skeleton3D,
	target_skeleton: Skeleton3D
) -> Animation:
	var clip := source.duplicate(true) as Animation
	clip.loop_mode = Animation.LOOP_NONE
	for index in range(clip.get_track_count()-1,-1,-1):
		var source_path := clip.track_get_path(index)
		var bone := String(source_path.get_concatenated_subnames())
		if bone == "Hips" and clip.track_get_type(index) == Animation.TYPE_POSITION_3D:
			clip.remove_track(index)
		elif not bone.is_empty():
			clip.track_set_path(index,NodePath("%s:%s" % [TARGET_SKELETON,bone]))
			if clip.track_get_type(index) == Animation.TYPE_ROTATION_3D:
				var source_bone := source_skeleton.find_bone(bone)
				var target_bone := target_skeleton.find_bone(bone)
				if source_bone >= 0 and target_bone >= 0:
					var rest_delta := target_skeleton.get_bone_rest(target_bone).basis.inverse()*source_skeleton.get_bone_rest(source_bone).basis
					var correction := rest_delta.get_rotation_quaternion()
					for key in clip.track_get_key_count(index):
						var rotation: Quaternion = clip.track_get_key_value(index,key)
						clip.track_set_key_value(index,key,correction*rotation)
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
			target_skeleton
		)


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
