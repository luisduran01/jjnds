extends Control

# ============================================================
# PRE-FIGHT CARD — Diamond Boxing
# Layout limpio, estético, funcional
# ============================================================

const COLOR_DIAMOND  = Color(0.45, 0.72, 1.0, 1.0)
const COLOR_PINK     = Color(1.0, 0.22, 0.58, 1.0)
const COLOR_BG_DARK  = Color(0.04, 0.04, 0.08, 1.0)
const COLOR_CARD     = Color(0.07, 0.07, 0.13, 0.92)
const AI_STYLES      = ["OUTBOXER", "PRESSURE FIGHTER", "COUNTER PUNCHER", "BRAWLER", "BALANCED"]

var is_finished : bool = false
var can_continue: bool = false

var p_bars    : Array = []
var e_bars    : Array = []
var p_targets : Array = []
var e_targets : Array = []

# Layout references for animation
var left_panel  : Control
var right_panel : Control
var center_card : Control
var bg_overlay  : ColorRect

# ============================================================
func _ready() -> void:
	_build_background()
	_load_and_build()
	
	# Clear any stale CinematicManager fade overlay
	var cm = get_node_or_null("/root/CinematicManager")
	if cm and cm.has_method("fade_out"):
		cm.fade_out(0.0)
	
	await get_tree().process_frame
	await get_tree().process_frame
	_play_sequence()

# ============================================================
# BACKGROUND
# ============================================================
func _build_background() -> void:
	# FIGHTCARD.PNG como fondo
	var bg_tex = TextureRect.new()
	var fightcard = load("res://assets/sprites/FIGHTCARD.png")
	if not fightcard:
		fightcard = load("res://assets/sprites/fondoquick.png")
	bg_tex.texture = fightcard
	bg_tex.set_anchors_preset(PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(0.55, 0.55, 0.65, 1.0)
	add_child(bg_tex)

	# Gradiente oscuro encima
	bg_overlay = ColorRect.new()
	bg_overlay.color = Color(0.0, 0.0, 0.0, 0.72)
	bg_overlay.set_anchors_preset(PRESET_FULL_RECT)
	bg_overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_overlay)

# ============================================================
# MAIN BUILD
# ============================================================
func _load_and_build() -> void:
	var gm = get_node_or_null("/root/GameManager")
	var p_data : BoxerData = BoxerData.new()
	var e_data : BoxerData = BoxerData.new()
	if gm:
		if gm.player_profile: p_data = gm.player_profile
		if gm.enemy_profile:  e_data = gm.enemy_profile

	# --- HEADER: "MAIN EVENT" ---
	var header_lbl = Label.new()
	header_lbl.text = "◆  MAIN EVENT  ◆"
	header_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	header_lbl.offset_top = 28; header_lbl.offset_bottom = 62
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_font_size_override("font_size", 20)
	header_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9, 0.9))
	add_child(header_lbl)

	# Divisor bajo header
	var top_line = ColorRect.new()
	top_line.set_anchors_preset(PRESET_TOP_WIDE)
	top_line.offset_top = 65; top_line.offset_bottom = 67
	top_line.offset_left = 60; top_line.offset_right = -60
	top_line.color = Color(1, 1, 1, 0.12)
	top_line.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(top_line)

	# --- LEFT PANEL (Player / Diamond) ---
	left_panel = _make_panel()
	left_panel.set_anchors_preset(PRESET_FULL_RECT)
	left_panel.anchor_right = 0.38
	left_panel.offset_top = 70; left_panel.offset_bottom = -80
	left_panel.offset_left = 30; left_panel.offset_right = -15
	add_child(left_panel)
	_fill_fighter_panel(left_panel, p_data, true)

	# --- RIGHT PANEL (Opponent / Pink) ---
	right_panel = _make_panel()
	right_panel.set_anchors_preset(PRESET_FULL_RECT)
	right_panel.anchor_left  = 0.62
	right_panel.anchor_right = 1.0
	right_panel.offset_top = 70; right_panel.offset_bottom = -80
	right_panel.offset_left = 15; right_panel.offset_right = -30
	add_child(right_panel)
	_fill_fighter_panel(right_panel, e_data, false)

	# --- CENTER CARD (VS + Stats) ---
	center_card = _make_panel()
	center_card.set_anchors_preset(PRESET_FULL_RECT)
	center_card.anchor_left  = 0.38
	center_card.anchor_right = 0.62
	center_card.offset_top = 70; center_card.offset_bottom = -80
	add_child(center_card)
	_fill_center(center_card, p_data, e_data)

	# --- FOOTER ---
	_build_footer()

	# Initially hidden for animation
	left_panel.modulate.a  = 0.0
	right_panel.modulate.a = 0.0
	center_card.modulate.a = 0.0

# ============================================================
# PANEL HELPERS
# ============================================================
func _make_panel() -> ColorRect:
	var cr = ColorRect.new()
	cr.color = COLOR_CARD
	return cr

func _fill_fighter_panel(panel: Control, data: BoxerData, is_player: bool) -> void:
	var accent = COLOR_DIAMOND if is_player else COLOR_PINK

	# Glow tint en el borde
	var border = ColorRect.new()
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.color = Color(accent.r, accent.g, accent.b, 0.18)
	border.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(border)

	# Borde accent (1px)
	var line_top = ColorRect.new()
	line_top.set_anchors_preset(PRESET_TOP_WIDE)
	line_top.offset_bottom = 3
	line_top.color = accent
	line_top.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(line_top)

	# Portrait / Sprite
	if data.portrait:
		var tex = TextureRect.new()
		tex.texture = data.portrait
		tex.set_anchors_preset(PRESET_FULL_RECT)
		tex.offset_top = 0; tex.offset_bottom = -160
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.flip_h = not is_player
		panel.add_child(tex)
		# Gradient bottom over portrait
		var grad_cover = ColorRect.new()
		grad_cover.set_anchors_preset(PRESET_FULL_RECT)
		grad_cover.offset_top = -160
		grad_cover.color = Color(0, 0, 0, 0)
		grad_cover.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(grad_cover)
	else:
		# Silhouette placeholder (no sprite fallback con imagen incorrecta)
		var sil = ColorRect.new()
		sil.color = Color(accent.r, accent.g, accent.b, 0.08)
		sil.set_anchors_preset(PRESET_FULL_RECT)
		sil.offset_bottom = -160
		sil.mouse_filter = MOUSE_FILTER_IGNORE
		panel.add_child(sil)
		var sil_lbl = Label.new()
		sil_lbl.text = "?" if data.boxer_name == "" else data.boxer_name[0].to_upper()
		sil_lbl.set_anchors_preset(PRESET_CENTER)
		sil_lbl.offset_left = -60; sil_lbl.offset_right = 60
		sil_lbl.offset_top = -120; sil_lbl.offset_bottom = -60
		sil_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sil_lbl.add_theme_font_size_override("font_size", 96)
		sil_lbl.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.25))
		panel.add_child(sil_lbl)

	# Info bottom strip
	var strip = ColorRect.new()
	strip.set_anchors_preset(PRESET_BOTTOM_WIDE)
	strip.offset_top = -158; strip.offset_bottom = 0
	strip.color = Color(0.03, 0.03, 0.06, 0.95)
	strip.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(strip)

	# OVR badge
	var ovr_bg = ColorRect.new()
	ovr_bg.color = accent
	ovr_bg.color.a = 0.85
	ovr_bg.set_anchors_preset(PRESET_BOTTOM_LEFT if is_player else PRESET_BOTTOM_RIGHT)
	if is_player:
		ovr_bg.offset_left = 12; ovr_bg.offset_top = -150
		ovr_bg.offset_right = 90; ovr_bg.offset_bottom = -120
	else:
		ovr_bg.offset_left = -90; ovr_bg.offset_top = -150
		ovr_bg.offset_right = -12; ovr_bg.offset_bottom = -120
	panel.add_child(ovr_bg)

	var ovr_lbl = Label.new()
	ovr_lbl.text = "%d" % data.overall
	ovr_lbl.set_anchors_preset(PRESET_FULL_RECT if false else ovr_bg.anchors_preset)
	ovr_lbl.anchor_left  = ovr_bg.anchor_left
	ovr_lbl.anchor_right = ovr_bg.anchor_right
	ovr_lbl.anchor_top   = ovr_bg.anchor_top
	ovr_lbl.anchor_bottom = ovr_bg.anchor_bottom
	ovr_lbl.offset_left  = ovr_bg.offset_left
	ovr_lbl.offset_right = ovr_bg.offset_right
	ovr_lbl.offset_top   = ovr_bg.offset_top
	ovr_lbl.offset_bottom = ovr_bg.offset_bottom
	ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ovr_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	ovr_lbl.add_theme_font_size_override("font_size", 22)
	panel.add_child(ovr_lbl)

	# Name
	var name_lbl = Label.new()
	name_lbl.text = data.boxer_name.to_upper()
	name_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	name_lbl.offset_top  = -118; name_lbl.offset_bottom = -78
	name_lbl.offset_left = 10;   name_lbl.offset_right  = -10
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(name_lbl)

	# Nickname
	if data.nickname.strip_edges() != "":
		var nick_lbl = Label.new()
		nick_lbl.text = '"%s"' % data.nickname
		nick_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
		nick_lbl.offset_top  = -80; nick_lbl.offset_bottom = -55
		nick_lbl.offset_left = 10;  nick_lbl.offset_right  = -10
		nick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
		nick_lbl.add_theme_font_size_override("font_size", 16)
		nick_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.78, 1))
		panel.add_child(nick_lbl)

	# Accent separator
	var sep = ColorRect.new()
	sep.set_anchors_preset(PRESET_BOTTOM_WIDE)
	sep.offset_top = -53; sep.offset_bottom = -51
	sep.offset_left = 10; sep.offset_right = -10
	sep.color = accent
	sep.color.a = 0.6
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(sep)

	# Style
	var style_idx = clampi(data.ai_style, 0, AI_STYLES.size() - 1)
	var style_lbl = Label.new()
	style_lbl.text = AI_STYLES[style_idx]
	style_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	style_lbl.offset_top  = -48; style_lbl.offset_bottom = -22
	style_lbl.offset_left = 10;  style_lbl.offset_right  = -10
	style_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
	style_lbl.add_theme_font_size_override("font_size", 14)
	style_lbl.add_theme_color_override("font_color", accent)
	panel.add_child(style_lbl)

	# Country
	if data.country.strip_edges() != "" and data.country.strip_edges() != "Unknown":
		var ctry_lbl = Label.new()
		ctry_lbl.text = data.country.to_upper()
		ctry_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
		ctry_lbl.offset_top  = -22; ctry_lbl.offset_bottom = -4
		ctry_lbl.offset_left = 10;  ctry_lbl.offset_right  = -10
		ctry_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_player else HORIZONTAL_ALIGNMENT_RIGHT
		ctry_lbl.add_theme_font_size_override("font_size", 12)
		ctry_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55, 1))
		panel.add_child(ctry_lbl)

# ============================================================
# CENTER PANEL: VS + Stats
# ============================================================
func _fill_center(panel: Control, p_data: BoxerData, e_data: BoxerData) -> void:
	# VS
	var vs_lbl = Label.new()
	vs_lbl.text = "VS"
	vs_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	vs_lbl.offset_top = 24; vs_lbl.offset_bottom = 80
	vs_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_lbl.add_theme_font_size_override("font_size", 52)
	vs_lbl.add_theme_color_override("font_color", Color.WHITE)
	panel.add_child(vs_lbl)

	# Blue half of VS glow (left)
	var glow_l = ColorRect.new()
	glow_l.color = Color(COLOR_DIAMOND.r, COLOR_DIAMOND.g, COLOR_DIAMOND.b, 0.12)
	glow_l.anchor_left = 0.0; glow_l.anchor_top = 0.0
	glow_l.anchor_right = 0.5; glow_l.anchor_bottom = 1.0
	glow_l.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(glow_l)
	panel.move_child(glow_l, vs_lbl.get_index())

	# Pink half of VS glow (right)
	var glow_r = ColorRect.new()
	glow_r.color = Color(COLOR_PINK.r, COLOR_PINK.g, COLOR_PINK.b, 0.12)
	glow_r.anchor_left = 0.5; glow_r.anchor_top = 0.0
	glow_r.anchor_right = 1.0; glow_r.anchor_bottom = 1.0
	glow_r.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(glow_r)
	panel.move_child(glow_r, vs_lbl.get_index())

	# Center divider
	var vert_div = ColorRect.new()
	vert_div.set_anchors_preset(PRESET_FULL_RECT)
	vert_div.offset_left = -1; vert_div.offset_right = 1
	vert_div.anchor_left = 0.5; vert_div.anchor_right = 0.5
	vert_div.color = Color(1, 1, 1, 0.08)
	vert_div.mouse_filter = MOUSE_FILTER_IGNORE
	panel.add_child(vert_div)

	# Stats section
	var stats_top = 90
	var stats_data = [
		["POWER",   p_data.power,   e_data.power],
		["SPEED",   p_data.speed,   e_data.speed],
		["STAMINA", int(p_data.stamina_max), int(e_data.stamina_max)],
		["DEFENSE", p_data.defense, e_data.defense],
		["CHIN",    p_data.chin,    e_data.chin],
	]
	var row_h = 38
	for i in stats_data.size():
		var sd = stats_data[i]
		var y = stats_top + i * row_h
		_add_stat_row_center(panel, sd[0], sd[1], sd[2], y)

func _add_stat_row_center(panel: Control, stat_name: String, p_val: int, e_val: int, y: int) -> void:
	# Stat label
	var lbl = Label.new()
	lbl.text = stat_name
	lbl.set_anchors_preset(PRESET_TOP_WIDE)
	lbl.offset_top = y; lbl.offset_bottom = y + 18
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	panel.add_child(lbl)

	# Player bar (left side, fills right-to-left)
	var p_bar = ProgressBar.new()
	p_bar.max_value = 100
	p_bar.value = 0
	p_bar.show_percentage = false
	p_bar.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	p_bar.anchor_left  = 0.0; p_bar.anchor_right = 0.5
	p_bar.anchor_top   = 0.0; p_bar.anchor_bottom = 0.0
	p_bar.offset_top   = y + 20; p_bar.offset_bottom = y + 34
	p_bar.offset_left  = 4;      p_bar.offset_right  = -6
	p_bar.modulate = COLOR_DIAMOND
	panel.add_child(p_bar)
	p_bars.append(p_bar)
	p_targets.append(p_val)

	# Enemy bar (right side, fills left-to-right)
	var e_bar = ProgressBar.new()
	e_bar.max_value = 100
	e_bar.value = 0
	e_bar.show_percentage = false
	e_bar.anchor_left  = 0.5; e_bar.anchor_right = 1.0
	e_bar.anchor_top   = 0.0; e_bar.anchor_bottom = 0.0
	e_bar.offset_top   = y + 20; e_bar.offset_bottom = y + 34
	e_bar.offset_left  = 6;      e_bar.offset_right  = -4
	e_bar.modulate = COLOR_PINK
	panel.add_child(e_bar)
	e_bars.append(e_bar)
	e_targets.append(e_val)

	# Value labels
	var p_val_lbl = Label.new()
	p_val_lbl.text = str(p_val)
	p_val_lbl.anchor_left  = 0.0; p_val_lbl.anchor_right = 0.5
	p_val_lbl.anchor_top   = 0.0; p_val_lbl.anchor_bottom = 0.0
	p_val_lbl.offset_top   = y + 20; p_val_lbl.offset_bottom = y + 36
	p_val_lbl.offset_left  = 4;      p_val_lbl.offset_right  = -6
	p_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	p_val_lbl.add_theme_font_size_override("font_size", 11)
	p_val_lbl.add_theme_color_override("font_color", COLOR_DIAMOND if p_val >= e_val else Color(0.55,0.55,0.6))
	panel.add_child(p_val_lbl)

	var e_val_lbl = Label.new()
	e_val_lbl.text = str(e_val)
	e_val_lbl.anchor_left  = 0.5; e_val_lbl.anchor_right = 1.0
	e_val_lbl.anchor_top   = 0.0; e_val_lbl.anchor_bottom = 0.0
	e_val_lbl.offset_top   = y + 20; e_val_lbl.offset_bottom = y + 36
	e_val_lbl.offset_left  = 6;      e_val_lbl.offset_right  = -4
	e_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	e_val_lbl.add_theme_font_size_override("font_size", 11)
	e_val_lbl.add_theme_color_override("font_color", COLOR_PINK if e_val >= p_val else Color(0.55,0.55,0.6))
	panel.add_child(e_val_lbl)

# ============================================================
# FOOTER
# ============================================================
func _build_footer() -> void:
	var footer_bg = ColorRect.new()
	footer_bg.set_anchors_preset(PRESET_BOTTOM_WIDE)
	footer_bg.offset_top = -78; footer_bg.offset_bottom = 0
	footer_bg.color = Color(0.03, 0.03, 0.06, 0.95)
	footer_bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(footer_bg)

	var bottom_line = ColorRect.new()
	bottom_line.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom_line.offset_top = -79; bottom_line.offset_bottom = -77
	bottom_line.offset_left = 60; bottom_line.offset_right = -60
	bottom_line.color = Color(1, 1, 1, 0.1)
	bottom_line.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bottom_line)

	var arena_lbl = Label.new()
	arena_lbl.text = "BOXING ARENA  •  EXHIBITION BOUT"
	arena_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	arena_lbl.offset_top = -64; arena_lbl.offset_bottom = -42
	arena_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arena_lbl.add_theme_font_size_override("font_size", 15)
	arena_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65, 1))
	add_child(arena_lbl)

	var cont_lbl = Label.new()
	cont_lbl.text = "PRESS ANY KEY TO FIGHT"
	cont_lbl.set_anchors_preset(PRESET_BOTTOM_WIDE)
	cont_lbl.offset_top = -38; cont_lbl.offset_bottom = -16
	cont_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cont_lbl.add_theme_font_size_override("font_size", 18)
	cont_lbl.add_theme_color_override("font_color", Color.WHITE)
	add_child(cont_lbl)

	# Blink
	var tw = create_tween().set_loops()
	tw.tween_property(cont_lbl, "modulate:a", 0.15, 0.7)
	tw.tween_property(cont_lbl, "modulate:a", 1.0,  0.7)

# ============================================================
# ANIMATION SEQUENCE
# ============================================================
func _play_sequence() -> void:
	var sm = get_node_or_null("/root/SoundManager")

	# Slide panels in
	left_panel.position.x  = -80
	right_panel.position.x =  80

	var tw_l = create_tween()
	tw_l.tween_property(left_panel,  "modulate:a", 1.0, 0.45)
	tw_l.parallel().tween_property(left_panel,  "position:x", 0.0, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	var tw_r = create_tween()
	tw_r.tween_property(right_panel, "modulate:a", 1.0, 0.45)
	tw_r.parallel().tween_property(right_panel, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.35).timeout

	# VS pop
	center_card.scale = Vector2(0.88, 0.88)
	var tw_c = create_tween()
	tw_c.tween_property(center_card, "modulate:a", 1.0,         0.35)
	tw_c.parallel().tween_property(center_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sm: sm.play("ko_bell", -6.0)

	# Animate bars
	await get_tree().create_timer(0.3).timeout
	for i in p_bars.size():
		var tw_b = create_tween()
		tw_b.tween_property(p_bars[i], "value", float(p_targets[i]), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw_b.parallel().tween_property(e_bars[i], "value", float(e_targets[i]), 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.6).timeout
	can_continue = true

# ============================================================
# INPUT & EXIT
# ============================================================
func _input(event: InputEvent) -> void:
	if is_finished: return
	if event.is_pressed() and not event.is_echo():
		if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
			_go_to_ring()

func _go_to_ring() -> void:
	if is_finished: return
	is_finished = true

	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("ui_select")

	# Own fade to black, then direct scene change
	var tw = create_tween()
	tw.tween_property(bg_overlay, "color:a", 1.0, 0.3)
	await tw.finished
	
	var err = get_tree().change_scene_to_file("res://scenes/arena/fight_3d.tscn")
	if err != OK:
		print("ERROR CRÍTICO AL CARGAR fight_3d.tscn: ", err)
