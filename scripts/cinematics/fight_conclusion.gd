extends Control

# ============================================================
# FIGHT CONCLUSION — Phase 5 Cinematic Polish
# Pantalla de resultado de pelea con presentación premium
# ============================================================

var winner_name: String = ""
var fight_method: String = ""
var fight_stats: Dictionary = {}
var is_finished: bool = false

# Nodos UI
var main_card: Control
var winner_banner: ColorRect
var winner_lbl: Label
var method_lbl: Label
var stats_vbox: VBoxContainer
var continue_btn: Button
var flash_rect: ColorRect

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Capa de oscuridad base
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.06, 0.92)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	# Flash blanco de impacto
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(PRESET_FULL_RECT)
	flash_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash_rect)

	# Tarjeta central
	main_card = Control.new()
	main_card.set_anchors_preset(PRESET_CENTER)
	main_card.custom_minimum_size = Vector2(640, 500)
	main_card.offset_left   = -320
	main_card.offset_right  =  320
	main_card.offset_top    = -260
	main_card.offset_bottom =  260
	add_child(main_card)

	# Borde oscuro de tarjeta
	var card_bg = ColorRect.new()
	card_bg.color = Color(0.07, 0.08, 0.12, 0.97)
	card_bg.set_anchors_preset(PRESET_FULL_RECT)
	card_bg.mouse_filter = MOUSE_FILTER_IGNORE
	main_card.add_child(card_bg)

	# Borde Diamond
	var border = ColorRect.new()
	border.color = Color(0.55, 0.75, 0.9, 0.35)
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -2; border.offset_top = -2
	border.offset_right = 2; border.offset_bottom = 2
	border.mouse_filter = MOUSE_FILTER_IGNORE
	main_card.add_child(border)

	# "THE WINNER IS..." label
	var title_lbl = Label.new()
	title_lbl.text = "THE WINNER IS..."
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	title_lbl.offset_top = 30; title_lbl.offset_bottom = 65
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9, 1))
	main_card.add_child(title_lbl)

	# Banda dorada para el nombre del ganador
	winner_banner = ColorRect.new()
	winner_banner.color = Color(0.12, 0.16, 0.24, 1)
	winner_banner.set_anchors_preset(PRESET_TOP_WIDE)
	winner_banner.offset_top = 70; winner_banner.offset_bottom = 148
	winner_banner.mouse_filter = MOUSE_FILTER_IGNORE
	main_card.add_child(winner_banner)

	# Nombre ganador
	winner_lbl = Label.new()
	winner_lbl.text = "---"
	winner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	winner_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	winner_lbl.offset_top = 70; winner_lbl.offset_bottom = 148
	winner_lbl.add_theme_font_size_override("font_size", 52)
	winner_lbl.add_theme_color_override("font_color", Color.WHITE)
	winner_lbl.add_theme_color_override("font_shadow_color", Color(0.3, 0.6, 1.0, 0.8))
	winner_lbl.add_theme_constant_override("shadow_outline_size", 6)
	main_card.add_child(winner_lbl)

	# Método (KO R3, UD, etc.)
	method_lbl = Label.new()
	method_lbl.text = ""
	method_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	method_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	method_lbl.offset_top = 158; method_lbl.offset_bottom = 194
	method_lbl.add_theme_font_size_override("font_size", 26)
	method_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3, 1))
	main_card.add_child(method_lbl)

	# Línea separadora
	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.75, 0.9, 0.25)
	sep.set_anchors_preset(PRESET_TOP_WIDE)
	sep.offset_top = 202; sep.offset_bottom = 204
	sep.offset_left = 40; sep.offset_right = -40
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	main_card.add_child(sep)

	# Stats VBox
	stats_vbox = VBoxContainer.new()
	stats_vbox.set_anchors_preset(PRESET_TOP_WIDE)
	stats_vbox.offset_top = 215; stats_vbox.offset_bottom = 395
	stats_vbox.offset_left = 40; stats_vbox.offset_right = -40
	stats_vbox.add_theme_constant_override("separation", 8)
	main_card.add_child(stats_vbox)

	# Botón continuar
	continue_btn = Button.new()
	continue_btn.text = "  CONTINUE  "
	continue_btn.set_anchors_preset(PRESET_BOTTOM_WIDE)
	continue_btn.offset_top = -60; continue_btn.offset_bottom = -20
	continue_btn.offset_left = 160; continue_btn.offset_right = -160
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.pressed.connect(_on_continue_pressed)
	main_card.add_child(continue_btn)

	main_card.modulate.a = 0.0
	hide()

func show_result(winner: String, method: String, stats: Dictionary) -> void:
	winner_name = winner.to_upper()
	fight_method = method
	fight_stats = stats
	show()
	_play_result_sequence()

func _play_result_sequence() -> void:
	var cm = get_node_or_null("/root/CinematicManager")
	var sm = get_node_or_null("/root/SoundManager")

	# Fade to black
	if cm:
		await cm.fade_in(0.6)

	winner_lbl.text = winner_name
	method_lbl.text = fight_method

	# Populate stats
	_build_stats()

	# Flash + reveal
	if cm: await cm.fade_out(0.4)

	# Flash blanco
	var tw_flash = create_tween()
	tw_flash.tween_property(flash_rect, "color:a", 0.7, 0.06)
	tw_flash.tween_property(flash_rect, "color:a", 0.0, 0.35)

	# Sound
	if sm: sm.play("ko_bell", 0.0)

	# Card pop in
	main_card.scale = Vector2(0.85, 0.85)
	var tw_card = create_tween()
	tw_card.tween_property(main_card, "modulate:a", 1.0, 0.35)
	tw_card.parallel().tween_property(main_card, "scale", Vector2(1.0, 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_card.finished

	if sm: sm.play("crowd_cheer", 0.0)

func _build_stats() -> void:
	# Limpiar stats anteriores
	for child in stats_vbox.get_children():
		child.queue_free()

	var rows = [
		["PLAYER LANDED", str(fight_stats.get("p_landed", 0)), str(fight_stats.get("e_landed", 0)), "ENEMY LANDED"],
		["PLAYER THROWN", str(fight_stats.get("p_thrown", 0)), str(fight_stats.get("e_thrown", 0)), "ENEMY THROWN"],
		["KNOCKDOWNS",    str(fight_stats.get("p_knockdowns", 0)), str(fight_stats.get("e_knockdowns", 0)), "KNOCKDOWNS"],
	]

	for row_data in rows:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		stats_vbox.add_child(row)

		var lbl_left = Label.new()
		lbl_left.text = row_data[0]
		lbl_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_left.add_theme_font_size_override("font_size", 15)
		lbl_left.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9, 1))
		row.add_child(lbl_left)

		var val_left = Label.new()
		val_left.text = row_data[1]
		val_left.add_theme_font_size_override("font_size", 18)
		val_left.add_theme_color_override("font_color", Color.WHITE)
		row.add_child(val_left)

		var divider = Label.new()
		divider.text = "  –  "
		divider.add_theme_font_size_override("font_size", 14)
		divider.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 1))
		row.add_child(divider)

		var val_right = Label.new()
		val_right.text = row_data[2]
		val_right.add_theme_font_size_override("font_size", 18)
		val_right.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
		row.add_child(val_right)

		var lbl_right = Label.new()
		lbl_right.text = row_data[3]
		lbl_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_right.add_theme_font_size_override("font_size", 15)
		lbl_right.add_theme_color_override("font_color", Color(0.75, 0.75, 0.78, 1))
		row.add_child(lbl_right)

func _on_continue_pressed() -> void:
	if is_finished: return
	is_finished = true

	var cm = get_node_or_null("/root/CinematicManager")
	var gm = get_node_or_null("/root/GameManager")

	var next_scene = "res://scenes/menus/main_menu.tscn"
	if gm and gm.is_career_mode:
		next_scene = "res://scenes/career/career_menu.tscn"

	if cm:
		cm.change_scene(next_scene)
	else:
		get_tree().change_scene_to_file(next_scene)
