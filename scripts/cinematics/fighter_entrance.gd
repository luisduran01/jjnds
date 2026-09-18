extends Control

# ============================================================
# FIGHTER ENTRANCE — Phase 5 Cinematic Polish
# Presenta al luchador con atmósfera completa antes del combate
# ============================================================

var is_finished: bool = false

# Nodes creados dinámicamente
var bg_overlay: ColorRect
var vignette: ColorRect
var fighter_name_lbl: Label
var fighter_subtitle_lbl: Label
var record_lbl: Label
var flash_rect: ColorRect
var portrait_rect: TextureRect
var text_container: VBoxContainer
var accent_line: ColorRect

func _ready() -> void:
	# Fondo negro total para iniciar
	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 1)
	bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	bg_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_overlay)

	# Vignette (oscurece los bordes)
	vignette = ColorRect.new()
	vignette.color = Color(0, 0, 0, 0)
	vignette.set_anchors_preset(PRESET_FULL_RECT)
	vignette.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(vignette)

	# Contenedor vertical centrado para todo el texto
	text_container = VBoxContainer.new()
	text_container.set_anchors_preset(PRESET_CENTER)
	text_container.offset_left = -400
	text_container.offset_right = 400
	text_container.offset_top = -150
	text_container.offset_bottom = 150
	text_container.alignment = BoxContainer.ALIGNMENT_CENTER
	text_container.add_theme_constant_override("separation", 10)
	add_child(text_container)

	# Subtítulo superior (FIGHT NIGHT / ENTRANCE)
	fighter_subtitle_lbl = Label.new()
	fighter_subtitle_lbl.text = "FIGHT NIGHT"
	fighter_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_subtitle_lbl.add_theme_font_size_override("font_size", 24)
	fighter_subtitle_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9, 0))
	text_container.add_child(fighter_subtitle_lbl)

	# Contenedor para la línea
	var line_center = CenterContainer.new()
	text_container.add_child(line_center)
	accent_line = ColorRect.new()
	accent_line.custom_minimum_size = Vector2(400, 4)
	accent_line.color = Color(0.55, 0.75, 0.9, 0)
	line_center.add_child(accent_line)

	# Nombre del luchador (grande, centrado)
	fighter_name_lbl = Label.new()
	fighter_name_lbl.text = "FIGHTER"
	fighter_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fighter_name_lbl.add_theme_font_size_override("font_size", 80)
	fighter_name_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	fighter_name_lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.6, 1.0, 0.8))
	fighter_name_lbl.add_theme_constant_override("shadow_outline_size", 8)
	text_container.add_child(fighter_name_lbl)

	# Récord abajo del nombre
	record_lbl = Label.new()
	record_lbl.text = ""
	record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_lbl.add_theme_font_size_override("font_size", 28)
	record_lbl.add_theme_color_override("font_color", Color(0.8, 0.7, 0.3, 0))
	text_container.add_child(record_lbl)

	# Flash blanco de impacto
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(PRESET_FULL_RECT)
	flash_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# Skip hint
	var skip_lbl = Label.new()
	skip_lbl.text = "[ ENTER / ESC ]  Skip"
	skip_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	skip_lbl.offset_top = -40
	skip_lbl.offset_bottom = -15
	skip_lbl.offset_right = -20
	skip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_lbl.add_theme_font_size_override("font_size", 16)
	skip_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))
	add_child(skip_lbl)

	_start_entrance()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		if not is_finished:
			_finish_entrance()

func _start_entrance() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var sm = get_node_or_null("/root/SoundManager")

	var boxer_name = "FIGHTER"
	var nickname = ""
	var record = ""
	var portrait_tex: Texture2D = null

	if gm and gm.player_profile:
		boxer_name = gm.player_profile.boxer_name.to_upper()
		nickname = gm.player_profile.nickname if "nickname" in gm.player_profile else ""
		if "portrait" in gm.player_profile and gm.player_profile.portrait != null:
			portrait_tex = gm.player_profile.portrait
		if gm.is_career_mode and gm.current_career:
			record = "%d - %d - %d" % [gm.current_career.wins, gm.current_career.losses, gm.current_career.draws]

	fighter_name_lbl.text = boxer_name
	fighter_subtitle_lbl.text = '"%s"' % nickname if nickname != "" else "FIGHT NIGHT"
	record_lbl.text = "RECORD: " + record if record != "" else ""

	# Reproducir sonido de multitud
	if sm: sm.play("crowd_cheer", 0.0)

	# Si hay retrato, mostrarlo de fondo con opacidad
	if portrait_tex:
		portrait_rect = TextureRect.new()
		portrait_rect.texture = portrait_tex
		portrait_rect.set_anchors_preset(PRESET_FULL_RECT)
		portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait_rect.modulate.a = 0.0
		# Put portrait behind text container
		add_child_below_node(text_container, portrait_rect)

	# ── SECUENCIA CINEMATOGRÁFICA ──────────────────────────────

	# Paso 1: Fade inicial del fondo negro
	var tw1 = create_tween()
	tw1.tween_property(bg_overlay, "color", Color(0.06, 0.06, 0.10, 1.0), 0.8)
	await tw1.finished
	if is_finished: return

	# Paso 2: Fade in retrato de fondo si existe
	if portrait_rect:
		var tw_p = create_tween()
		tw_p.tween_property(portrait_rect, "modulate:a", 0.35, 0.6)

	# Paso 3: Aparece subtítulo
	var tw2 = create_tween()
	tw2.tween_property(fighter_subtitle_lbl, "modulate:a", 1.0, 0.5)
	await tw2.finished
	if is_finished: return

	await get_tree().create_timer(0.3).timeout
	if is_finished: return

	# Paso 4: Línea decorativa aparece
	var tw3 = create_tween()
	tw3.tween_property(accent_line, "color", Color(0.55, 0.75, 0.9, 0.8), 0.4)

	# Paso 5: Flash blanco + Nombre con scale pop
	fighter_name_lbl.modulate.a = 0.0
	fighter_name_lbl.scale = Vector2(0.7, 0.7)

	var tw_flash = create_tween()
	tw_flash.tween_property(flash_rect, "color:a", 0.6, 0.05)
	tw_flash.tween_property(flash_rect, "color:a", 0.0, 0.25)

	await get_tree().create_timer(0.05).timeout

	var tw_name = create_tween()
	tw_name.tween_property(fighter_name_lbl, "modulate:a", 1.0, 0.25)
	tw_name.parallel().tween_property(fighter_name_lbl, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_name.finished
	if is_finished: return

	# Paso 6: Récord
	var tw_rec = create_tween()
	tw_rec.tween_property(record_lbl, "modulate:a", 1.0, 0.4)
	await tw_rec.finished
	if is_finished: return

	# Paso 7: Mantener 2 segundos y luego salir
	await get_tree().create_timer(2.2).timeout
	if is_finished: return

	_finish_entrance()

func _finish_entrance() -> void:
	if is_finished: return
	is_finished = true

	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		await cm.fade_in(0.5)
		await cm.fade_out(0.3)
	else:
		var tw = create_tween()
		tw.tween_property(bg_overlay, "color:a", 1.0, 0.5)
		await tw.finished

	get_tree().change_scene_to_file("res://assets/main.tscn")
