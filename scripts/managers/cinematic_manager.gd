extends CanvasLayer

# ============================================================
# CINEMATIC MANAGER — Autoload
# Sistema central que gestiona todas las cinemáticas del juego.
# Controla: fade, tarjetas de texto, bloqueo de input, skip.
# ============================================================

signal cinematic_started
signal cinematic_finished
signal cinematic_skipped

# ---- Nodos internos ----
var _fade_rect: ColorRect
var _card_container: Control
var _card_label_top: Label
var _card_label_main: Label
var _card_label_sub: Label
var _skip_hint: Label

# ---- Estado ----
var _is_playing: bool = false
var _skip_requested: bool = false
var _controls_blocked: bool = false

# Referencia al jugador para bloquear input
var _player_ref: Node = null


func _ready() -> void:
	layer = 100  # Por encima de todo
	_build_ui()


func _build_ui() -> void:
	# --- Fondo oscuro para fade ---
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.modulate.a = 0.0
	add_child(_fade_rect)

	# --- Contenedor de tarjeta de texto ---
	_card_container = Control.new()
	_card_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_container.visible = false
	add_child(_card_container)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_container.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(800, 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_child(vbox)

	_card_label_top = Label.new()
	_card_label_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label_top.add_theme_font_size_override("font_size", 20)
	_card_label_top.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	vbox.add_child(_card_label_top)

	_card_label_main = Label.new()
	_card_label_main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label_main.add_theme_font_size_override("font_size", 56)
	_card_label_main.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_card_label_main)

	_card_label_sub = Label.new()
	_card_label_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label_sub.add_theme_font_size_override("font_size", 22)
	_card_label_sub.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3, 1))
	vbox.add_child(_card_label_sub)

	# --- Hint de skip ---
	_skip_hint = Label.new()
	_skip_hint.text = "[ ENTER / ESC ] Skip"
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_skip_hint.offset_top = -40
	_skip_hint.add_theme_font_size_override("font_size", 16)
	_skip_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	_skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_hint.visible = false
	add_child(_skip_hint)


# ============================================================
# INPUT — Detectar Skip
# ============================================================

func _input(event: InputEvent) -> void:
	if not _is_playing:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_skip_requested = true


# ============================================================
# FADE IN / OUT  (pantalla negra)
# ============================================================

func fade_in(duration: float = 0.5) -> void:
	"""Oscurecer la pantalla (negro)"""
	var tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 1.0, duration)
	await tween.finished


func fade_out(duration: float = 0.5) -> void:
	"""Aclarar la pantalla desde negro"""
	var tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", 0.0, duration)
	await tween.finished


# ============================================================
# TARJETA DE TEXTO  ("FIGHT NIGHT", "ROUND 1", etc.)
# ============================================================

func show_card(main_text: String, sub_text: String = "", top_text: String = "",
			   hold_duration: float = 2.5, skippable: bool = true) -> void:
	"""Muestra una tarjeta cinematográfica con texto central."""
	_is_playing = true
	_skip_requested = false

	_card_label_top.text = top_text.to_upper()
	_card_label_main.text = main_text.to_upper()
	_card_label_sub.text = sub_text.to_upper()
	_card_container.modulate.a = 0.0
	_card_container.visible = true
	_skip_hint.visible = skippable

	cinematic_started.emit()

	# Fade in de la tarjeta
	var tween_in = create_tween()
	tween_in.tween_property(_card_container, "modulate:a", 1.0, 0.5)
	await tween_in.finished

	# Esperar (con posibilidad de skip)
	var elapsed = 0.0
	while elapsed < hold_duration:
		if _skip_requested:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	# Fade out de la tarjeta
	var tween_out = create_tween()
	tween_out.tween_property(_card_container, "modulate:a", 0.0, 0.4)
	await tween_out.finished

	_card_container.visible = false
	_skip_hint.visible = false
	_is_playing = false

	if _skip_requested:
		cinematic_skipped.emit()
	else:
		cinematic_finished.emit()


# ============================================================
# SECUENCIA DE TARJETAS
# ============================================================

func play_card_sequence(cards: Array, skippable: bool = true) -> void:
	"""
	Reproduce una lista de tarjetas en orden.
	cards = [ {main, sub, top, duration}, ... ]
	"""
	_is_playing = true
	_skip_requested = false
	_skip_hint.visible = skippable
	cinematic_started.emit()

	for card in cards:
		if _skip_requested:
			break
		var main = card.get("main", "")
		var sub  = card.get("sub", "")
		var top  = card.get("top", "")
		var dur  = card.get("duration", 2.5)

		_card_label_top.text  = top.to_upper()
		_card_label_main.text = main.to_upper()
		_card_label_sub.text  = sub.to_upper()
		_card_container.modulate.a = 0.0
		_card_container.visible = true

		var tw_in = create_tween()
		tw_in.tween_property(_card_container, "modulate:a", 1.0, 0.45)
		await tw_in.finished

		var elapsed = 0.0
		while elapsed < dur and not _skip_requested:
			await get_tree().process_frame
			elapsed += get_process_delta_time()

		var tw_out = create_tween()
		tw_out.tween_property(_card_container, "modulate:a", 0.0, 0.35)
		await tw_out.finished

	_card_container.visible = false
	_skip_hint.visible = false
	_is_playing = false

	if _skip_requested:
		cinematic_skipped.emit()
	else:
		cinematic_finished.emit()


# ============================================================
# CAMBIO DE ESCENA CON TRANSICIÓN
# ============================================================

func change_scene(path: String, fade_duration: float = 0.4) -> void:
	"""Fade to black → cambiar escena → Fade from black."""
	_is_playing = true
	await fade_in(fade_duration)
	get_tree().change_scene_to_file(path)
	await fade_out(fade_duration)
	_is_playing = false


func change_scene_with_card(path: String, main_text: String,
							sub_text: String = "", duration: float = 2.5) -> void:
	"""Muestra tarjeta, luego cambia de escena."""
	await fade_in(0.3)
	_card_label_top.text = ""
	_card_label_main.text = main_text.to_upper()
	_card_label_sub.text = sub_text.to_upper()
	_card_container.modulate.a = 1.0
	_card_container.visible = true
	await get_tree().create_timer(duration).timeout
	get_tree().change_scene_to_file(path)
	var tw = create_tween()
	tw.tween_property(_fade_rect, "modulate:a", 0.0, 0.5)
	_card_container.visible = false
	await tw.finished
	_is_playing = false


# ============================================================
# BLOQUEO DE CONTROLES
# ============================================================

func block_player_input(player: Node) -> void:
	"""Llama a esto antes de una cinemática para desactivar al jugador."""
	_player_ref = player
	if player and player.has_method("set"):
		player.set("can_attack", false)
		if player.has_method("set_physics_process"):
			player.set_physics_process(false)


func unblock_player_input() -> void:
	"""Reactiva el jugador al terminar la cinemática."""
	if _player_ref and is_instance_valid(_player_ref):
		_player_ref.set("can_attack", true)
		if _player_ref.has_method("set_physics_process"):
			_player_ref.set_physics_process(true)
	_player_ref = null


# ============================================================
# HELPERS
# ============================================================

func is_playing() -> bool:
	return _is_playing


func get_safe_animation(sprite: AnimatedSprite2D, anim_name: String, fallback: String = "idle") -> String:
	"""Devuelve el nombre de animación si existe, si no usa fallback."""
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
		return anim_name
	return fallback


func play_safe(sprite: AnimatedSprite2D, anim_name: String, fallback: String = "idle") -> void:
	"""Reproduce una animación con fallback seguro."""
	var anim = get_safe_animation(sprite, anim_name, fallback)
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)
