extends Control

# ============================================================
# PRE-FIGHT CARD CINEMATIC
# ============================================================

const COLOR_DIAMOND = Color(0.55, 0.75, 0.9, 1)
const COLOR_PINK = Color(0.9, 0.2, 0.6, 1)
const AI_STYLES = ["OUTBOXER", "PRESSURE FIGHTER", "COUNTER PUNCHER", "BRAWLER", "BALANCED"]

var is_finished: bool = false
var can_continue: bool = false

# Lados
var p_root: Control
var e_root: Control
var center_root: Control
var bg_overlay: ColorRect

# Animaciones de barras
var p_bars = []
var e_bars = []
var p_targets = []
var e_targets = []

func _ready() -> void:
	# 1. Preparar Background
	var bg_tex = TextureRect.new()
	bg_tex.texture = load("res://assets/sprites/fondoquick.png") # Arena oscura / humo
	bg_tex.set_anchors_preset(PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(0.4, 0.4, 0.5, 1)
	add_child(bg_tex)
	
	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0, 0, 0, 0.8)
	bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg_overlay)
	
	# Clear any CinematicManager fade overlay that may have been left black
	var cm = get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("fade_out"):
		cm.fade_out(0.0)

	# Nodos principales
	p_root = Control.new()
	p_root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(p_root)
	
	e_root = Control.new()
	e_root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(e_root)
	
	center_root = Control.new()
	center_root.set_anchors_preset(PRESET_FULL_RECT)
	add_child(center_root)
	
	# Ocultar todo inicialmente
	p_root.modulate.a = 0
	e_root.modulate.a = 0
	center_root.modulate.a = 0
	
	_load_fight_data()
	
	# Pequeño delay antes de iniciar la secuencia
	await get_tree().create_timer(0.3).timeout
	_play_intro_sequence()

func _load_fight_data() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var cm = get_node_or_null("/root/CareerManager") # Para futuro
	
	var p_data: BoxerData = null
	var e_data: BoxerData = null
	
	if gm:
		p_data = gm.player_profile
		e_data = gm.enemy_profile
		
	# Fallbacks
	if not p_data: p_data = BoxerData.new()
	if not e_data: e_data = BoxerData.new()
	
	_build_fighter_side(p_root, p_data, true)
	_build_fighter_side(e_root, e_data, false)
	_build_center_stats(p_data, e_data)
	_build_header_footer()

func _build_fighter_side(root: Control, data: BoxerData, is_player: bool) -> void:
	var anchor_x = 0.2 if is_player else 0.8
	var color = COLOR_DIAMOND if is_player else COLOR_PINK
	
	# Glow de fondo
	var glow = ColorRect.new()
	glow.color = color
	glow.color.a = 0.15
	glow.set_anchors_preset(PRESET_FULL_RECT)
	
	# Portrait o Sprite
	if data.portrait:
		var tex = TextureRect.new()
		tex.texture = data.portrait
		tex.set_anchors_preset(PRESET_CENTER)
		tex.offset_left = -300 if is_player else 60
		tex.offset_right = -60 if is_player else 300
		tex.offset_top = -200
		tex.offset_bottom = 200
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.flip_h = not is_player
		root.add_child(tex)
	else:
		# Fallback a sprite
		var spr = Sprite2D.new()
		var s_tex = load("res://assets/sprites/publico.png")
		if s_tex:
			spr.texture = s_tex
			spr.region_enabled = true
			spr.region_rect = Rect2(0, 0, 100, 150)
		spr.scale = Vector2(3.0, 3.0)
		spr.position = Vector2(250 if is_player else 1030, 350)
		spr.flip_h = not is_player
		root.add_child(spr)
		
	# Contenedor de Textos
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_TOP_LEFT if is_player else PRESET_TOP_RIGHT)
	vbox.offset_top = 100
	vbox.offset_bottom = 300
	if is_player:
		vbox.offset_left = 80
		vbox.offset_right = 450
	else:
		vbox.offset_left = -450
		vbox.offset_right = -80
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(vbox)
	
	# OVR
	var ovr_lbl = Label.new()
	ovr_lbl.text = "%d OVR" % data.overall
	ovr_lbl.add_theme_font_size_override("font_size", 42)
	ovr_lbl.add_theme_color_override("font_color", color)
	ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(ovr_lbl)
	
	# Name
	var name_lbl = Label.new()
	name_lbl.text = data.boxer_name.to_upper()
	name_lbl.add_theme_font_size_override("font_size", 48)
	name_lbl.add_theme_color_override("font_shadow_color", color * 0.5)
	name_lbl.add_theme_constant_override("shadow_outline_size", 6)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(name_lbl)
	
	# Nickname
	if data.nickname != "":
		var nick_lbl = Label.new()
		nick_lbl.text = '"%s"' % data.nickname
		nick_lbl.add_theme_font_size_override("font_size", 22)
		nick_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		nick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
		vbox.add_child(nick_lbl)
		
	# Separator
	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 4)
	sep.color = color
	vbox.add_child(sep)
	
	# Style
	var style_lbl = Label.new()
	var style_name = AI_STYLES[data.ai_style] if data.ai_style >= 0 and data.ai_style < AI_STYLES.size() else "BALANCED"
	style_lbl.text = style_name
	style_lbl.add_theme_font_size_override("font_size", 18)
	style_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	style_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(style_lbl)

func _build_center_stats(p_data: BoxerData, e_data: BoxerData) -> void:
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_CENTER)
	vbox.offset_left = -220
	vbox.offset_right = 220
	vbox.offset_top = -120
	vbox.offset_bottom = 200
	vbox.add_theme_constant_override("separation", 24)
	center_root.add_child(vbox)
	
	# VS logo
	var vs_lbl = Label.new()
	vs_lbl.text = "VS"
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_size_override("font_size", 64)
	vs_lbl.add_theme_color_override("font_color", Color.WHITE)
	vs_lbl.add_theme_constant_override("shadow_outline_size", 10)
	vbox.add_child(vs_lbl)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)
	
	# Stats comparativas
	_add_stat_row(vbox, "POWER", p_data.power, e_data.power)
	_add_stat_row(vbox, "SPEED", p_data.speed, e_data.speed)
	_add_stat_row(vbox, "STAMINA", int(p_data.stamina_max), int(e_data.stamina_max))
	_add_stat_row(vbox, "DEFENSE", p_data.defense, e_data.defense)
	_add_stat_row(vbox, "CHIN", p_data.chin, e_data.chin)

func _add_stat_row(parent: VBoxContainer, stat_name: String, p_val: int, e_val: int) -> void:
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 15)
	parent.add_child(hbox)
	
	# P Val
	var p_lbl = Label.new()
	p_lbl.text = str(p_val)
	p_lbl.add_theme_font_size_override("font_size", 20)
	p_lbl.add_theme_color_override("font_color", COLOR_DIAMOND if p_val >= e_val else Color(0.6,0.6,0.6))
	hbox.add_child(p_lbl)
	
	# P Bar
	var p_bar = ProgressBar.new()
	p_bar.custom_minimum_size = Vector2(120, 14)
	p_bar.show_percentage = false
	p_bar.max_value = 100
	p_bar.value = 0
	p_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	p_bar.modulate = COLOR_DIAMOND
	hbox.add_child(p_bar)
	p_bars.append(p_bar)
	p_targets.append(p_val)
	
	# Name
	var n_lbl = Label.new()
	n_lbl.text = stat_name
	n_lbl.custom_minimum_size = Vector2(100, 0)
	n_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(n_lbl)
	
	# E Bar
	var e_bar = ProgressBar.new()
	e_bar.custom_minimum_size = Vector2(120, 14)
	e_bar.show_percentage = false
	e_bar.max_value = 100
	e_bar.value = 0
	e_bar.modulate = COLOR_PINK
	hbox.add_child(e_bar)
	e_bars.append(e_bar)
	e_targets.append(e_val)
	
	# E Val
	var e_lbl = Label.new()
	e_lbl.text = str(e_val)
	e_lbl.add_theme_font_size_override("font_size", 20)
	e_lbl.add_theme_color_override("font_color", COLOR_PINK if e_val >= p_val else Color(0.6,0.6,0.6))
	hbox.add_child(e_lbl)

func _build_header_footer() -> void:
	var rounds = 3 # Default; round_manager only exists inside main.tscn at fight time
	var header = Label.new()
	header.text = "MAIN EVENT"
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_top = 30
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	header.add_theme_constant_override("letter_spacing", 4)
	center_root.add_child(header)
	
	var footer = Label.new()
	footer.text = "BOXING ARENA • EXHIBITION"
	footer.set_anchors_preset(PRESET_BOTTOM_WIDE)
	footer.offset_bottom = -80
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 18)
	footer.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	center_root.add_child(footer)
	
	var cont_lbl = Label.new()
	cont_lbl.text = "PRESS ANY KEY TO CONTINUE"
	cont_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	cont_lbl.offset_bottom = -25
	cont_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cont_lbl.add_theme_font_size_override("font_size", 16)
	cont_lbl.add_theme_color_override("font_color", Color.WHITE)
	center_root.add_child(cont_lbl)
	
	# Blink anim
	var tw = create_tween().set_loops()
	tw.tween_property(cont_lbl, "modulate:a", 0.2, 0.8)
	tw.tween_property(cont_lbl, "modulate:a", 1.0, 0.8)

func _play_intro_sequence() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	
	# 1. Fade background
	var tw_bg = create_tween()
	tw_bg.tween_property(bg_overlay, "color:a", 0.4, 0.8)
	
	# 2. Slide Player from left
	p_root.position.x = -100
	var tw_p = create_tween()
	tw_p.tween_property(p_root, "modulate:a", 1.0, 0.5)
	tw_p.parallel().tween_property(p_root, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.4).timeout
	
	# 3. Slide Enemy from right
	e_root.position.x = 100
	var tw_e = create_tween()
	tw_e.tween_property(e_root, "modulate:a", 1.0, 0.5)
	tw_e.parallel().tween_property(e_root, "position:x", 0.0, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.5).timeout
	if sm: sm.play("ko_bell", -5.0)
	
	# 4. Show Center + VS Impact
	center_root.scale = Vector2(1.2, 1.2)
	var tw_c = create_tween()
	tw_c.tween_property(center_root, "modulate:a", 1.0, 0.4)
	tw_c.parallel().tween_property(center_root, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# 5. Animate Stat Bars
	await get_tree().create_timer(0.3).timeout
	for i in range(p_bars.size()):
		var tw_bar = create_tween()
		tw_bar.tween_property(p_bars[i], "value", p_targets[i], 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_bar.parallel().tween_property(e_bars[i], "value", e_targets[i], 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(0.6).timeout
	can_continue = true

func _input(event: InputEvent) -> void:
	if not can_continue or is_finished:
		return
	var pressed = false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	elif event is InputEventJoypadButton and event.pressed:
		pressed = true
	if pressed:
		_finish_entrance()

func _finish_entrance() -> void:
	if is_finished: return
	is_finished = true
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("ui_select")
	
	# Fade to black using our own overlay, then change scene directly.
	# Never rely on CinematicManager here — it can block or leave a black overlay.
	var tw = create_tween()
	tw.tween_property(bg_overlay, "color:a", 1.0, 0.35)
	await tw.finished
	get_tree().change_scene_to_file("res://assets/main.tscn")
