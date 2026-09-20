extends Control

# ===========================================================
# QUICK FIGHT — Todo construido por código (inmune a Godot editor override)
# ===========================================================

var roster: Array = []
var p1_index: int = 0
var p2_index: int = 1
var is_transitioning: bool = false

# Referencias a nodos de UI (creados en _build_ui)
var p1_name_lbl: Label
var p1_nick_lbl: Label
var p1_ovr_lbl: Label
var p1_style_lbl: Label
var p1_bars: Dictionary = {}
var p1_preview_root: Control
var p1_sprite: AnimatedSprite2D
var p1_portrait: TextureRect

var p2_name_lbl: Label
var p2_nick_lbl: Label
var p2_ovr_lbl: Label
var p2_style_lbl: Label
var p2_bars: Dictionary = {}
var p2_preview_root: Control
var p2_sprite: AnimatedSprite2D
var p2_portrait: TextureRect

var vs_label: Label
var bottom_panel: Control

const AI_STYLE_NAMES = {
	0: "BRAWLER", 1: "OUTBOXER", 2: "COUNTER PUNCHER",
	3: "PRESSURE FIGHTER", 4: "BALANCED", 5: "TECHNICAL"
}
const STAT_NAMES = ["POWER", "SPEED", "STAMINA", "DEFENSE", "CHIN"]
const BAR_COLOR_P1 = Color(0.25, 0.55, 1.0, 1.0)
const BAR_COLOR_P2 = Color(0.7,  0.7,  0.75, 1.0)

func _ready() -> void:
	load_roster()
	_build_ui()
	update_ui()
	_play_entrance_animation()
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_bgm"):
		sm.play_bgm("select")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()

# ----------------------------------------------------------
# CARGA DE BOXEADORES
# ----------------------------------------------------------
func load_roster() -> void:
	var dir = DirAccess.open("res://resources/boxers/")
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				roster.append(load("res://resources/boxers/" + f))
			f = dir.get_next()
	if roster.size() == 0:
		push_error("QuickFight: No boxers in res://resources/boxers/")

# ----------------------------------------------------------
# CONSTRUCCIÓN DE UI POR CÓDIGO
# ----------------------------------------------------------
func _build_ui() -> void:
	# ── FONDO ──────────────────────────────────────────────
	var bg_tex = TextureRect.new()
	bg_tex.set_anchors_preset(PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	var tex = load("res://assets/sprites/fondoquick.png")
	if tex: bg_tex.texture = tex
	bg_tex.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_tex)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0.02, 0.55)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)

	# ── CABECERA ───────────────────────────────────────────
	var hdr = _make_label("QUICK FIGHT", 30, Color.WHITE)
	hdr.set_anchors_preset(PRESET_TOP_WIDE)
	hdr.offset_top = 12; hdr.offset_bottom = 50
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hdr)

	var sub = _make_label("CHOOSE YOUR FIGHTERS", 15, Color(0.55, 0.75, 0.9, 1))
	sub.set_anchors_preset(PRESET_TOP_WIDE)
	sub.offset_top = 50; sub.offset_bottom = 72
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var hline = ColorRect.new()
	hline.color = Color(0.55, 0.75, 0.9, 0.4)
	hline.set_anchors_preset(PRESET_TOP_WIDE)
	hline.offset_top = 73; hline.offset_bottom = 75
	hline.offset_left = 80; hline.offset_right = -80
	hline.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(hline)

	# ── LADO IZQUIERDO (PLAYER 1) ──────────────────────────
	var left = Control.new()
	left.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	left.anchor_right = 0.42
	left.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(left)
	p1_preview_root = left

	var p1_title = _make_label("PLAYER 1", 16, Color(0.55, 0.75, 0.9, 1))
	p1_title.position = Vector2(60, 85)
	left.add_child(p1_title)

	# Área de personaje
	var p1_glow = ColorRect.new()
	p1_glow.color = Color(0.2, 0.45, 0.85, 0.07)
	p1_glow.position = Vector2(50, 110); p1_glow.size = Vector2(310, 300)
	p1_glow.mouse_filter = MOUSE_FILTER_IGNORE
	left.add_child(p1_glow)

	p1_sprite = AnimatedSprite2D.new()
	p1_sprite.position = Vector2(210, 240)
	p1_sprite.scale = Vector2(1.2, 1.2)
	left.add_child(p1_sprite)
	
	p1_portrait = TextureRect.new()
	p1_portrait.position = Vector2(80, 130)
	p1_portrait.size = Vector2(250, 240)
	p1_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p1_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left.add_child(p1_portrait)

	var p1_shadow = ColorRect.new()
	p1_shadow.color = Color(0, 0, 0, 0.35)
	p1_shadow.position = Vector2(80, 405); p1_shadow.size = Vector2(250, 12)
	p1_shadow.mouse_filter = MOUSE_FILTER_IGNORE
	left.add_child(p1_shadow)

	# Flechas P1
	var btn_p1_prev = _make_arrow_btn("◀")
	btn_p1_prev.position = Vector2(15, 290)
	btn_p1_prev.pressed.connect(func(): change_p1(-1))
	left.add_child(btn_p1_prev)

	var btn_p1_next = _make_arrow_btn("▶")
	btn_p1_next.position = Vector2(360, 290)
	btn_p1_next.pressed.connect(func(): change_p1(1))
	left.add_child(btn_p1_next)

	# Info P1
	p1_name_lbl = _make_label("ALONSO", 28, Color.WHITE)
	p1_name_lbl.position = Vector2(40, 425)
	p1_name_lbl.size = Vector2(360, 40)
	p1_name_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,1))
	p1_name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	p1_name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	left.add_child(p1_name_lbl)

	p1_nick_lbl = _make_label('"THE ROOKIE"', 16, Color(0.55, 0.75, 0.9, 1))
	p1_nick_lbl.position = Vector2(40, 460)
	p1_nick_lbl.size = Vector2(360, 24)
	left.add_child(p1_nick_lbl)

	p1_ovr_lbl = _make_label("68\nOVR", 32, Color(0.85, 0.75, 0.3, 1))
	p1_ovr_lbl.position = Vector2(40, 488)
	p1_ovr_lbl.size = Vector2(120, 70)
	left.add_child(p1_ovr_lbl)

	p1_style_lbl = _make_label("BALANCED", 13, Color(0.6, 0.6, 0.6, 1))
	p1_style_lbl.position = Vector2(170, 510)
	p1_style_lbl.size = Vector2(200, 24)
	left.add_child(p1_style_lbl)

	# Barras P1
	p1_bars = _build_bars(left, Vector2(40, 570), BAR_COLOR_P1, false)

	# ── CENTRO ─────────────────────────────────────────────
	var center = Control.new()
	center.anchor_left = 0.42; center.anchor_right = 0.58
	center.anchor_top = 0; center.anchor_bottom = 1
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	var vline = ColorRect.new()
	vline.color = Color(0.55, 0.75, 0.9, 0.18)
	vline.anchor_left = 0.5; vline.anchor_right = 0.5
	vline.anchor_top = 0.1;  vline.anchor_bottom = 0.88
	vline.offset_left = -1;  vline.offset_right = 1
	vline.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(vline)

	vs_label = _make_label("VS", 72, Color.WHITE)
	vs_label.set_anchors_preset(PRESET_CENTER)
	vs_label.offset_left = -55; vs_label.offset_top = -55
	vs_label.offset_right = 55; vs_label.offset_bottom = 55
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vs_label.add_theme_color_override("font_shadow_color", Color(0.2, 0.5, 1.0, 0.9))
	vs_label.add_theme_constant_override("shadow_outline_size", 8)
	vs_label.add_theme_constant_override("shadow_offset_x", 0)
	vs_label.add_theme_constant_override("shadow_offset_y", 0)
	center.add_child(vs_label)

	# ── LADO DERECHO (CPU) ─────────────────────────────────
	var right = Control.new()
	right.anchor_left = 0.58; right.anchor_right = 1.0
	right.anchor_top = 0;     right.anchor_bottom = 1
	right.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(right)
	p2_preview_root = right

	var p2_title = _make_label("CPU", 16, Color(0.75, 0.75, 0.75, 1))
	p2_title.position = Vector2(10, 85)
	right.add_child(p2_title)

	var p2_glow = ColorRect.new()
	p2_glow.color = Color(0.7, 0.7, 0.7, 0.05)
	p2_glow.position = Vector2(20, 110); p2_glow.size = Vector2(310, 300)
	p2_glow.mouse_filter = MOUSE_FILTER_IGNORE
	right.add_child(p2_glow)

	p2_sprite = AnimatedSprite2D.new()
	p2_sprite.position = Vector2(175, 240)
	p2_sprite.scale = Vector2(1.2, 1.2)
	p2_sprite.flip_h = true
	right.add_child(p2_sprite)
	
	p2_portrait = TextureRect.new()
	p2_portrait.position = Vector2(50, 130)
	p2_portrait.size = Vector2(250, 240)
	p2_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p2_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(p2_portrait)

	var p2_shadow = ColorRect.new()
	p2_shadow.color = Color(0, 0, 0, 0.35)
	p2_shadow.position = Vector2(50, 405); p2_shadow.size = Vector2(250, 12)
	p2_shadow.mouse_filter = MOUSE_FILTER_IGNORE
	right.add_child(p2_shadow)

	# Flechas P2
	var btn_p2_prev = _make_arrow_btn("◀")
	btn_p2_prev.position = Vector2(0, 290)
	btn_p2_prev.pressed.connect(func(): change_p2(-1))
	right.add_child(btn_p2_prev)

	var btn_p2_next = _make_arrow_btn("▶")
	btn_p2_next.position = Vector2(340, 290)
	btn_p2_next.pressed.connect(func(): change_p2(1))
	right.add_child(btn_p2_next)

	# Info P2
	p2_name_lbl = _make_label("ALONSO", 28, Color.WHITE)
	p2_name_lbl.position = Vector2(10, 425)
	p2_name_lbl.size = Vector2(360, 40)
	p2_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_name_lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,1))
	p2_name_lbl.add_theme_constant_override("shadow_offset_x", 2)
	p2_name_lbl.add_theme_constant_override("shadow_offset_y", 2)
	right.add_child(p2_name_lbl)

	p2_nick_lbl = _make_label('"THE ROOKIE"', 16, Color(0.75, 0.75, 0.75, 1))
	p2_nick_lbl.position = Vector2(10, 460)
	p2_nick_lbl.size = Vector2(360, 24)
	p2_nick_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(p2_nick_lbl)

	p2_ovr_lbl = _make_label("68\nOVR", 32, Color(0.85, 0.75, 0.3, 1))
	p2_ovr_lbl.position = Vector2(240, 488)
	p2_ovr_lbl.size = Vector2(120, 70)
	p2_ovr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(p2_ovr_lbl)

	p2_style_lbl = _make_label("BALANCED", 13, Color(0.6, 0.6, 0.6, 1))
	p2_style_lbl.position = Vector2(10, 510)
	p2_style_lbl.size = Vector2(200, 24)
	p2_style_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	right.add_child(p2_style_lbl)

	# Barras P2 (espejadas)
	p2_bars = _build_bars(right, Vector2(10, 570), BAR_COLOR_P2, true)

	# ── BOTTOM ─────────────────────────────────────────────
	bottom_panel = Control.new()
	bottom_panel.set_anchors_preset(PRESET_BOTTOM_WIDE)
	bottom_panel.offset_top = -85
	bottom_panel.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bottom_panel)

	var info_lbl = _make_label("3 ROUNDS  •  BOXING ARENA", 14, Color(0.5, 0.5, 0.5, 1))
	info_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	info_lbl.offset_bottom = 25
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom_panel.add_child(info_lbl)

	var fight_btn = Button.new()
	fight_btn.text = "  START FIGHT  "
	fight_btn.set_anchors_preset(PRESET_CENTER)
	fight_btn.offset_left = -130; fight_btn.offset_top = 10
	fight_btn.offset_right = 130; fight_btn.offset_bottom = 58
	fight_btn.add_theme_font_size_override("font_size", 22)
	fight_btn.pressed.connect(_on_fight_pressed)
	bottom_panel.add_child(fight_btn)

	# ── BACK ───────────────────────────────────────────────
	var back_btn = Button.new()
	back_btn.text = "← BACK"
	back_btn.flat = true
	back_btn.position = Vector2(20, 16)
	back_btn.size = Vector2(110, 36)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)

# ----------------------------------------------------------
# HELPERS DE CONSTRUCCIÓN
# ----------------------------------------------------------
func _make_label(txt: String, size: int, col: Color) -> Label:
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	return lbl

func _make_arrow_btn(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.flat = true
	btn.size = Vector2(50, 50)
	btn.add_theme_font_size_override("font_size", 28)
	return btn

func _build_bars(parent: Control, origin: Vector2, fill_col: Color, mirror: bool) -> Dictionary:
	var bars = {}
	var y = 0.0
	for stat in STAT_NAMES:
		var row = Control.new()
		row.position = origin + Vector2(0, y)
		row.size = Vector2(360, 22)
		row.mouse_filter = MOUSE_FILTER_IGNORE
		parent.add_child(row)

		var lbl = _make_label(stat, 13, Color(0.7, 0.7, 0.7, 1))
		lbl.size = Vector2(80, 20)
		lbl.position = Vector2(0, 2) if not mirror else Vector2(280, 2)
		row.add_child(lbl)

		var track = ColorRect.new()
		track.color = Color(0.12, 0.12, 0.18, 1)
		track.position = Vector2(82, 6) if not mirror else Vector2(0, 6)
		track.size = Vector2(260, 11)
		track.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(track)

		var fill = ColorRect.new()
		fill.color = fill_col
		fill.position = track.position
		fill.size = Vector2(0, 11)
		fill.mouse_filter = MOUSE_FILTER_IGNORE
		row.add_child(fill)

		bars[stat] = fill
		y += 26.0
	return bars

# ----------------------------------------------------------
# ACTUALIZACIÓN DE UI
# ----------------------------------------------------------
func update_ui() -> void:
	if roster.size() == 0: return
	_update_side(roster[p1_index], p1_name_lbl, p1_nick_lbl, p1_ovr_lbl,
		p1_style_lbl, p1_bars, p1_sprite, p1_portrait, false)
	_update_side(roster[p2_index], p2_name_lbl, p2_nick_lbl, p2_ovr_lbl,
		p2_style_lbl, p2_bars, p2_sprite, p2_portrait, true)

func _update_side(boxer, name_l, nick_l, ovr_l, style_l, bars, sprite, portrait_rect, flip) -> void:
	if not boxer: return
	name_l.text  = boxer.boxer_name.to_upper()
	nick_l.text  = '"' + boxer.nickname + '"'
	ovr_l.text   = str(boxer.overall) + "\nOVR"
	style_l.text = AI_STYLE_NAMES.get(boxer.ai_style, "BALANCED")

	var stat_values = {
		"POWER":   boxer.power,
		"SPEED":   boxer.speed,
		"STAMINA": int(boxer.stamina_max),
		"DEFENSE": boxer.defense,
		"CHIN":    boxer.chin
	}
	for stat in STAT_NAMES:
		if bars.has(stat):
			_animate_bar(bars[stat], stat_values.get(stat, 50))

	if "portrait" in boxer and boxer.portrait != null:
		portrait_rect.texture = boxer.portrait
		portrait_rect.show()
		if sprite: sprite.hide()
	else:
		portrait_rect.hide()
		if sprite and sprite is AnimatedSprite2D:
			sprite.show()
			sprite.flip_h = flip
			if not sprite.sprite_frames:
				var dummy = load("res://assets/player.tscn").instantiate()
				var sf = dummy.get_node("AnimatedSprite2D").sprite_frames
				sprite.sprite_frames = sf
				dummy.queue_free()
			if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")

func _animate_bar(fill: ColorRect, value: int) -> void:
	var max_w = 260.0
	var target = clampf(value / 100.0, 0.0, 1.0) * max_w
	fill.size.x = 0
	var tw = create_tween()
	tw.tween_property(fill, "size:x", target, 0.45).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

# ----------------------------------------------------------
# CAMBIO DE PERSONAJE
# ----------------------------------------------------------
func change_p1(dir: int) -> void:
	if is_transitioning or roster.size() == 0: return
	p1_index = posmod(p1_index + dir, roster.size())
	_swap_anim(p1_preview_root, dir < 0)

func change_p2(dir: int) -> void:
	if is_transitioning or roster.size() == 0: return
	p2_index = posmod(p2_index + dir, roster.size())
	_swap_anim(p2_preview_root, dir > 0)

func _swap_anim(root: Control, to_left: bool) -> void:
	is_transitioning = true
	var off = -40.0 if to_left else 40.0
	var tw = create_tween()
	tw.tween_property(root, "modulate:a", 0.0, 0.12)
	tw.parallel().tween_property(root, "position:x", root.position.x + off, 0.12)
	await tw.finished
	update_ui()
	root.position.x -= off * 2
	var tw2 = create_tween()
	tw2.tween_property(root, "modulate:a", 1.0, 0.18)
	tw2.parallel().tween_property(root, "position:x", root.position.x + off * 2, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tw2.finished
	is_transitioning = false

# ----------------------------------------------------------
# ANIMACIÓN DE ENTRADA
# ----------------------------------------------------------
func _play_entrance_animation() -> void:
	p1_preview_root.modulate.a = 0.0
	p2_preview_root.modulate.a = 0.0
	vs_label.modulate.a = 0.0
	vs_label.scale = Vector2(0.5, 0.5)
	bottom_panel.modulate.a = 0.0

	var orig_p1x = p1_preview_root.position.x
	var orig_p2x = p2_preview_root.position.x
	p1_preview_root.position.x -= 50
	p2_preview_root.position.x += 50

	var tw = create_tween()
	tw.tween_property(p1_preview_root, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(p1_preview_root, "position:x", orig_p1x, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(p2_preview_root, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(p2_preview_root, "position:x", orig_p2x, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(vs_label, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(vs_label, "scale", Vector2(1, 1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(bottom_panel, "modulate:a", 1.0, 0.3)

# ----------------------------------------------------------
# BOTONES
# ----------------------------------------------------------
func _on_fight_pressed() -> void:
	if is_transitioning or roster.size() == 0: return
	is_transitioning = true

	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("menu_select")

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player_profile = roster[p1_index]
		gm.enemy_profile  = roster[p2_index]
		gm.is_career_mode = false

	var p1_name = roster[p1_index].boxer_name if roster.size() > 0 else "PLAYER"
	var p2_name = roster[p2_index].boxer_name if roster.size() > 0 else "CPU"

	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		await cm.fade_in(0.4)
	get_tree().change_scene_to_file("res://scenes/cinematics/pre_fight_card.tscn")

func _go_back() -> void:
	var cm = get_node_or_null("/root/CinematicManager")
	if cm: cm.change_scene("res://scenes/menus/main_menu.tscn")
	else: get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
