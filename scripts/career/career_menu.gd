extends Control

# ===========================================================
# CAREER HUB - Phase 1 Visual Overhaul (Diamond Style)
# ===========================================================

var career_mgr: CareerManager

# --- UI State ---
var tabs = ["HOME", "TRAINING", "FIGHTS", "RANKINGS", "HISTORY"]
var active_tab: int = 0
var tab_buttons: Array = []
var tab_panels: Array = []
var is_transitioning: bool = false

# --- Home Panel Refs ---
var player_sprite: AnimatedSprite2D
var player_portrait: TextureRect
var record_lbl: Label
var rank_lbl: Label
var next_opp_name: Label
var next_opp_rec: Label
var next_opp_ovr: Label
var money_lbl: Label
var power_fill: ColorRect
var speed_fill: ColorRect
var stamina_fill: ColorRect
var defense_fill: ColorRect
var chin_fill: ColorRect
var fights_opp_name_lbl: Label
var rankings_vbox: VBoxContainer

const COLOR_DIAMOND = Color(0.55, 0.75, 0.9, 1)
const COLOR_ACCENT = Color(0.2, 0.45, 0.85, 1)
const STAT_NAMES = ["POWER", "SPEED", "STAMINA", "DEFENSE", "CHIN"]

func _ready() -> void:
	career_mgr = CareerManager.new()
	add_child(career_mgr)
	career_mgr.career_loaded.connect(_on_career_loaded)
	
	_build_ui()
	
	if career_mgr.has_save():
		career_mgr.load_career()
	else:
		_show_new_career_select()
		
	_play_entrance_animation()

func _input(event: InputEvent) -> void:
	if is_transitioning: return
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	elif event.is_action_pressed("ui_right"):
		_change_tab(active_tab + 1)
	elif event.is_action_pressed("ui_left"):
		_change_tab(active_tab - 1)

# ----------------------------------------------------------
# UI BUILDING (CODE ONLY)
# ----------------------------------------------------------
func _build_ui() -> void:
	# 1. Background & Overlay
	var bg_tex = TextureRect.new()
	bg_tex.set_anchors_preset(PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_SCALE
	var tex = load("res://assets/sprites/fondomenu.png")
	if tex: bg_tex.texture = tex
	bg_tex.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_tex)

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0.05, 0.75) # Dark cinematic overlay
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)

	# 2. Header
	var header = Control.new()
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.offset_bottom = 80
	add_child(header)
	
	var title = _make_label("CAREER", 32, Color.WHITE)
	title.position = Vector2(40, 20)
	title.add_theme_color_override("font_shadow_color", Color(0,0,0,1))
	header.add_child(title)
	
	rank_lbl = _make_label("RANK #--", 20, COLOR_DIAMOND)
	rank_lbl.set_anchors_preset(PRESET_TOP_RIGHT)
	rank_lbl.offset_left = -250; rank_lbl.offset_top = 20
	rank_lbl.offset_right = -40; rank_lbl.offset_bottom = 50
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(rank_lbl)
	
	money_lbl = _make_label("$0", 20, Color(0.4, 0.9, 0.4, 1))
	money_lbl.set_anchors_preset(PRESET_TOP_RIGHT)
	money_lbl.offset_left = -250; money_lbl.offset_top = 45
	money_lbl.offset_right = -40; money_lbl.offset_bottom = 75
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(money_lbl)

	# 3. Tab Navigation
	var nav = HBoxContainer.new()
	nav.set_anchors_preset(PRESET_TOP_WIDE)
	nav.offset_top = 90; nav.offset_bottom = 120
	nav.offset_left = 40; nav.offset_right = -40
	nav.add_theme_constant_override("separation", 40)
	add_child(nav)
	
	var hline = ColorRect.new()
	hline.set_anchors_preset(PRESET_TOP_WIDE)
	hline.offset_top = 125; hline.offset_bottom = 126
	hline.color = Color(1, 1, 1, 0.1)
	add_child(hline)
	
	for i in range(tabs.size()):
		var btn = Button.new()
		btn.text = tabs[i]
		btn.flat = true
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1))
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.pressed.connect(func(): _change_tab(i))
		nav.add_child(btn)
		tab_buttons.append(btn)
		
		# Create a panel for each tab
		var panel = Control.new()
		panel.set_anchors_preset(PRESET_FULL_RECT)
		panel.offset_top = 140
		panel.visible = false
		add_child(panel)
		tab_panels.append(panel)
		
	# Build the HOME tab (Index 0)
	_build_home_tab(tab_panels[0])
	_build_training_tab(tab_panels[1])
	_build_fights_tab(tab_panels[2])
	_build_rankings_tab(tab_panels[3])
	_build_history_tab(tab_panels[4])

	# 4. Global Back Button
	var back_btn = Button.new()
	back_btn.text = "ESC / BACK"
	back_btn.flat = true
	back_btn.set_anchors_preset(PRESET_BOTTOM_LEFT)
	back_btn.position = Vector2(20, -50)
	back_btn.add_theme_font_size_override("font_size", 14)
	back_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	back_btn.pressed.connect(_go_back)
	add_child(back_btn)
	
	# Init first tab
	tab_panels[0].visible = true
	_highlight_tab(0)

func _build_home_tab(parent: Control) -> void:
	# -- Left: Boxer Profile Preview --
	var preview_root = Control.new()
	preview_root.set_anchors_and_offsets_preset(PRESET_LEFT_WIDE)
	preview_root.anchor_right = 0.35
	parent.add_child(preview_root)
	
	var p_glow = ColorRect.new()
	p_glow.color = Color(0.2, 0.45, 0.85, 0.05)
	p_glow.position = Vector2(40, 20); p_glow.size = Vector2(300, 360)
	p_glow.mouse_filter = MOUSE_FILTER_IGNORE
	preview_root.add_child(p_glow)
	
	player_sprite = AnimatedSprite2D.new()
	player_sprite.position = Vector2(190, 240)
	player_sprite.scale = Vector2(1.2, 1.2)
	preview_root.add_child(player_sprite)
	
	player_portrait = TextureRect.new()
	player_portrait.position = Vector2(70, 40)
	player_portrait.size = Vector2(240, 280)
	player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_root.add_child(player_portrait)
	
	record_lbl = _make_label("0-0-0", 24, COLOR_DIAMOND)
	record_lbl.position = Vector2(40, 390)
	record_lbl.size = Vector2(300, 40)
	record_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_root.add_child(record_lbl)
	
	var pro_lbl = _make_label("PRO RECORD", 12, Color(0.5,0.5,0.5,1))
	pro_lbl.position = Vector2(40, 420)
	pro_lbl.size = Vector2(300, 20)
	pro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_root.add_child(pro_lbl)

	# -- Center: Next Fight Card --
	var next_card = _make_card(Vector2(400, 20), Vector2(460, 200))
	parent.add_child(next_card)
	
	var nf_lbl = _make_label("NEXT FIGHT", 18, COLOR_DIAMOND)
	nf_lbl.position = Vector2(20, 20)
	next_card.add_child(nf_lbl)
	
	next_opp_name = _make_label("VS UNKNOWN", 28, Color.WHITE)
	next_opp_name.position = Vector2(20, 50)
	next_card.add_child(next_opp_name)
	
	next_opp_rec = _make_label("0-0-0", 14, Color(0.7,0.7,0.7,1))
	next_opp_rec.position = Vector2(20, 85)
	next_card.add_child(next_opp_rec)
	
	next_opp_ovr = _make_label("OVR --", 16, Color(0.8,0.7,0.3,1))
	next_opp_ovr.position = Vector2(20, 105)
	next_card.add_child(next_opp_ovr)
	
	var fight_btn = Button.new()
	fight_btn.text = " START FIGHT "
	fight_btn.position = Vector2(20, 140)
	fight_btn.size = Vector2(180, 40)
	fight_btn.add_theme_font_size_override("font_size", 16)
	fight_btn.pressed.connect(_on_fight_pressed)
	next_card.add_child(fight_btn)
	
	var time_lbl = _make_label("21 DAYS", 22, Color(0.4, 0.4, 0.45, 1))
	time_lbl.set_anchors_preset(PRESET_TOP_RIGHT)
	time_lbl.offset_left = -120; time_lbl.offset_top = 20
	time_lbl.offset_right = -20; time_lbl.offset_bottom = 50
	time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	next_card.add_child(time_lbl)

	# -- Bottom Center: Fighter Progress --
	var prog_card = _make_card(Vector2(400, 240), Vector2(460, 230))
	parent.add_child(prog_card)
	
	var fp_lbl = _make_label("FIGHTER PROGRESS", 14, Color(0.7,0.7,0.7,1))
	fp_lbl.position = Vector2(20, 15)
	prog_card.add_child(fp_lbl)
	
	var y = 45
	var bars = []
	for stat in STAT_NAMES:
		var lbl = _make_label(stat, 12, Color(0.6,0.6,0.6,1))
		lbl.position = Vector2(20, y)
		prog_card.add_child(lbl)
		
		var track = ColorRect.new()
		track.color = Color(1,1,1, 0.1)
		track.position = Vector2(90, y+3); track.size = Vector2(340, 10)
		prog_card.add_child(track)
		
		var fill = ColorRect.new()
		fill.color = COLOR_DIAMOND
		fill.position = track.position; fill.size = Vector2(0, 10)
		prog_card.add_child(fill)
		bars.append(fill)
		
		y += 32
		
	power_fill = bars[0]
	speed_fill = bars[1]
	stamina_fill = bars[2]
	defense_fill = bars[3]
	chin_fill = bars[4]

	# -- Right: Training Camp Summary --
	var train_card = _make_card(Vector2(880, 20), Vector2(240, 200))
	parent.add_child(train_card)
	
	var tc_lbl = _make_label("TRAINING CAMP", 14, Color(0.7,0.7,0.7,1))
	tc_lbl.position = Vector2(20, 15)
	train_card.add_child(tc_lbl)
	
	var en_lbl = _make_label("ENERGY", 12, Color(0.6,0.6,0.6,1))
	en_lbl.position = Vector2(20, 50)
	train_card.add_child(en_lbl)
	
	var en_bar = ColorRect.new()
	en_bar.color = Color(0.2, 0.8, 0.3, 1)
	en_bar.position = Vector2(20, 70); en_bar.size = Vector2(200, 12)
	train_card.add_child(en_bar)
	
	var gym_btn = Button.new()
	gym_btn.text = "GO TO GYM"
	gym_btn.position = Vector2(20, 140)
	gym_btn.size = Vector2(200, 40)
	gym_btn.add_theme_font_size_override("font_size", 14)
	gym_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/training/training_menu.tscn"))
	train_card.add_child(gym_btn)
func _build_training_tab(parent: Control) -> void:
	var title = _make_label("TRAINING CAMP", 20, COLOR_DIAMOND)
	title.position = Vector2(40, 20)
	parent.add_child(title)
	
	var status_card = _make_card(Vector2(40, 60), Vector2(300, 200))
	parent.add_child(status_card)
	
	var sl = _make_label("STATUS", 14, Color(0.7,0.7,0.7,1))
	sl.position = Vector2(20, 15)
	status_card.add_child(sl)
	
	var energy_lbl = _make_label("ENERGY", 12, Color(0.6,0.6,0.6,1))
	energy_lbl.position = Vector2(20, 50)
	status_card.add_child(energy_lbl)
	
	var en_bar = ColorRect.new()
	en_bar.color = Color(0.2, 0.8, 0.3, 1)
	en_bar.position = Vector2(20, 70); en_bar.size = Vector2(260, 12)
	status_card.add_child(en_bar)

	var fitness_lbl = _make_label("FITNESS", 12, Color(0.6,0.6,0.6,1))
	fitness_lbl.position = Vector2(20, 100)
	status_card.add_child(fitness_lbl)
	
	var fit_bar = ColorRect.new()
	fit_bar.color = Color(0.2, 0.6, 0.9, 1)
	fit_bar.position = Vector2(20, 120); fit_bar.size = Vector2(260, 12)
	status_card.add_child(fit_bar)
	
	var exercises = [
		{"name": "HEAVY BAG", "benefit": "POWER +", "cost": "ENERGY -10"},
		{"name": "SPEED BAG", "benefit": "SPEED +", "cost": "ENERGY -10"},
		{"name": "SPARRING",  "benefit": "SHARPNESS +", "cost": "ENERGY -20"},
		{"name": "ROADWORK",  "benefit": "STAMINA +", "cost": "ENERGY -15"},
		{"name": "JUMP ROPE", "benefit": "FOOTWORK +", "cost": "ENERGY -8"},
		{"name": "RECOVERY",  "benefit": "ENERGY ++", "cost": "REST"}
	]
	
	var start_x = 380
	var start_y = 60
	var col = 0
	var row = 0
	
	for ex in exercises:
		var card = _make_card(Vector2(start_x + (col * 240), start_y + (row * 120)), Vector2(220, 100))
		parent.add_child(card)
		
		var n_lbl = _make_label(ex.name, 16, Color.WHITE)
		n_lbl.position = Vector2(15, 15)
		card.add_child(n_lbl)
		
		var b_lbl = _make_label(ex.benefit, 12, Color(0.4, 0.9, 0.4, 1))
		b_lbl.position = Vector2(15, 45)
		card.add_child(b_lbl)
		
		var c_lbl = _make_label(ex.cost, 12, Color(0.9, 0.4, 0.4, 1))
		c_lbl.position = Vector2(15, 65)
		card.add_child(c_lbl)
		
		var btn = Button.new()
		btn.text = "TRAIN"
		btn.position = Vector2(120, 50)
		btn.size = Vector2(80, 35)
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/training/training_menu.tscn"))
		card.add_child(btn)
		
		col += 1
		if col > 2:
			col = 0
			row += 1

func _build_rankings_tab(parent: Control) -> void:
	var title = _make_label("WORLD RANKINGS", 20, COLOR_DIAMOND)
	title.position = Vector2(40, 20)
	parent.add_child(title)
	
	var card = _make_card(Vector2(40, 60), Vector2(800, 400))
	parent.add_child(card)
	
	var header_box = HBoxContainer.new()
	header_box.position = Vector2(20, 20)
	header_box.size = Vector2(760, 30)
	card.add_child(header_box)
	
	var r_lbl = _make_label("RANK", 14, Color(0.6,0.6,0.6,1))
	r_lbl.custom_minimum_size = Vector2(80, 0)
	header_box.add_child(r_lbl)
	
	var n_lbl = _make_label("FIGHTER", 14, Color(0.6,0.6,0.6,1))
	n_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_box.add_child(n_lbl)
	
	var o_lbl = _make_label("OVR", 14, Color(0.6,0.6,0.6,1))
	o_lbl.custom_minimum_size = Vector2(60, 0)
	o_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header_box.add_child(o_lbl)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 60)
	scroll.size = Vector2(780, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	
	rankings_vbox = VBoxContainer.new()
	rankings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rankings_vbox.add_theme_constant_override("separation", 5)
	scroll.add_child(rankings_vbox)

func _build_history_tab(parent: Control) -> void:
	var title = _make_label("FIGHT HISTORY", 20, COLOR_DIAMOND)
	title.position = Vector2(40, 20)
	parent.add_child(title)
	
	var card = _make_card(Vector2(40, 60), Vector2(800, 400))
	parent.add_child(card)
	
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(20, 20)
	scroll.size = Vector2(760, 360)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	# Since we don't have a real history array in CareerData yet, 
	# we'll build a visual placeholder list to show the design.
	var dummy_history = [
		{"res": "WIN", "opp": "Diego Cruz", "method": "KO R3", "date": "2026"},
		{"res": "WIN", "opp": "Alex Volkov", "method": "UD", "date": "2026"},
		{"res": "LOSS", "opp": "Malik Johnson", "method": "SD", "date": "2026"},
		{"res": "WIN", "opp": "Kenji Sato", "method": "KO R1", "date": "2025"}
	]
	
	for fight in dummy_history:
		var entry = ColorRect.new()
		entry.custom_minimum_size = Vector2(740, 60)
		entry.color = Color(1,1,1, 0.03)
		vbox.add_child(entry)
		
		var color = Color(0.3, 0.9, 0.3, 1) if fight.res == "WIN" else Color(0.9, 0.3, 0.3, 1)
		var res_lbl = _make_label(fight.res, 18, color)
		res_lbl.position = Vector2(20, 18)
		entry.add_child(res_lbl)
		
		var opp_lbl = _make_label("vs " + fight.opp.to_upper(), 18, Color.WHITE)
		opp_lbl.position = Vector2(100, 18)
		entry.add_child(opp_lbl)
		
		var meth_lbl = _make_label(fight.method, 14, Color(0.6,0.6,0.6,1))
		meth_lbl.position = Vector2(400, 22)
		entry.add_child(meth_lbl)
		
		var date_lbl = _make_label(fight.date, 14, Color(0.5,0.5,0.5,1))
		date_lbl.position = Vector2(650, 22)
		entry.add_child(date_lbl)

func _build_fights_tab(parent: Control) -> void:
	var title = _make_label("FIGHT OFFERS & CONTRACTS", 20, COLOR_DIAMOND)
	title.position = Vector2(40, 20)
	parent.add_child(title)
	
	var card = _make_card(Vector2(40, 60), Vector2(800, 300))
	parent.add_child(card)
	
	var head = _make_label("UPCOMING RANKED BOUT", 16, Color.WHITE)
	head.position = Vector2(20, 20)
	card.add_child(head)
	
	var opp_title = _make_label("OPPONENT", 12, Color(0.6,0.6,0.6,1))
	opp_title.position = Vector2(20, 60)
	card.add_child(opp_title)
	
	# We'll rely on the existing _on_fight_pressed logic for the actual fight
	# But visually let's set up the contract
	fights_opp_name_lbl = _make_label("WAITING FOR OPPONENT...", 28, Color.WHITE)
	fights_opp_name_lbl.position = Vector2(20, 80)
	card.add_child(fights_opp_name_lbl)
	
	var purse_lbl = _make_label("PURSE: $12,500", 16, Color(0.4, 0.9, 0.4, 1))
	purse_lbl.position = Vector2(20, 130)
	card.add_child(purse_lbl)
	
	var loc_lbl = _make_label("VENUE: CITY ARENA\nROUNDS: 8", 14, Color(0.7,0.7,0.7,1))
	loc_lbl.position = Vector2(20, 160)
	card.add_child(loc_lbl)
	
	var btn_accept = Button.new()
	btn_accept.text = " ACCEPT FIGHT / SIGN CONTRACT "
	btn_accept.position = Vector2(20, 220)
	btn_accept.size = Vector2(300, 50)
	btn_accept.add_theme_font_size_override("font_size", 18)
	btn_accept.pressed.connect(_on_fight_pressed)
	card.add_child(btn_accept)

# ----------------------------------------------------------
# HELPERS
# ----------------------------------------------------------
func _make_label(txt: String, size: int, col: Color) -> Label:
	var lbl = Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", col)
	return lbl

func _make_card(pos: Vector2, sz: Vector2) -> Control:
	var c = Control.new()
	c.position = pos
	c.size = sz
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.07, 0.8) # Dark slightly transparent
	c.add_child(bg)
	
	var outline = ColorRect.new()
	outline.set_anchors_preset(PRESET_FULL_RECT)
	outline.color = Color.TRANSPARENT
	outline.mouse_filter = MOUSE_FILTER_IGNORE
	c.add_child(outline)
	
	# Draw outline script-side
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1,1,1,0.1), false, 1.0)
	)
	
	return c

# ----------------------------------------------------------
# LOGIC & ANIMATIONS
# ----------------------------------------------------------
func _change_tab(idx: int) -> void:
	if is_transitioning: return
	if idx < 0: idx = tabs.size() - 1
	if idx >= tabs.size(): idx = 0
	if idx == active_tab: return
	
	is_transitioning = true
	var old_panel = tab_panels[active_tab]
	var new_panel = tab_panels[idx]
	active_tab = idx
	
	_highlight_tab(idx)
	
	# Transition
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("menu_select")
	
	var tw = create_tween()
	tw.tween_property(old_panel, "modulate:a", 0.0, 0.15)
	await tw.finished
	old_panel.visible = false
	
	new_panel.modulate.a = 0.0
	new_panel.visible = true
	var tw2 = create_tween()
	tw2.tween_property(new_panel, "modulate:a", 1.0, 0.15)
	await tw2.finished
	is_transitioning = false

func _highlight_tab(idx: int) -> void:
	for i in range(tab_buttons.size()):
		if i == idx:
			tab_buttons[i].add_theme_color_override("font_color", COLOR_DIAMOND)
		else:
			tab_buttons[i].add_theme_color_override("font_color", Color(0.5,0.5,0.5,1))

func _play_entrance_animation() -> void:
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUART)

# ----------------------------------------------------------
# CAREER DATA BINDING
# ----------------------------------------------------------
func _show_new_career_select() -> void:
	var roster = career_mgr.full_ranking
	if roster.size() == 0:
		rank_lbl.text = "NO ROSTER"
		return
	var default_boxer = roster[roster.size() - 1]
	for b in roster:
		if b.boxer_name == "Alonso":
			default_boxer = b
			break
	career_mgr.create_new_career(default_boxer)

func _on_career_loaded(career: CareerData) -> void:
	if not career: return
	
	rank_lbl.text = "RANK #" + str(career.rank)
	money_lbl.text = "$" + str(career.money)
	record_lbl.text = str(career.wins) + " - " + str(career.losses) + " - " + str(career.draws)
	
	# Find player boxer data to update sprite and stats
	var p_data = load(career.boxer_data_path) if ResourceLoader.exists(career.boxer_data_path) else null
	if p_data:
		if "portrait" in p_data and p_data.portrait != null:
			player_portrait.texture = p_data.portrait
			player_portrait.show()
			player_sprite.hide()
		else:
			player_portrait.hide()
			player_sprite.show()
			if not player_sprite.sprite_frames:
				var dummy = load("res://assets/player.tscn").instantiate()
				var sf = dummy.get_node("AnimatedSprite2D").sprite_frames
				player_sprite.sprite_frames = sf
				dummy.queue_free()
			if player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("idle"):
				player_sprite.play("idle")
		_animate_bar(power_fill, p_data.power)
		_animate_bar(speed_fill, p_data.speed)
		_animate_bar(stamina_fill, p_data.stamina_max)
		_animate_bar(defense_fill, p_data.defense)
		_animate_bar(chin_fill, p_data.chin)
		
	var opp = career_mgr.get_next_opponent()
	if opp:
		next_opp_name.text = "VS " + opp.boxer_name.to_upper()
		next_opp_ovr.text = "OVR " + str(opp.overall)
		# Guess record based on rank for flavor
		var wins = int(randf_range(5, 25))
		var losses = int(randf_range(0, 5))
		next_opp_rec.text = str(wins) + "-" + str(losses) + "-0"
		
		if fights_opp_name_lbl:
			fights_opp_name_lbl.text = opp.boxer_name.to_upper()
	else:
		next_opp_name.text = "VS TBD"
		next_opp_rec.text = ""
		next_opp_ovr.text = ""
		if fights_opp_name_lbl:
			fights_opp_name_lbl.text = "WAITING FOR OPPONENT..."

	# Populate Rankings Tab
	if rankings_vbox:
		for child in rankings_vbox.get_children():
			child.queue_free()
		var ranking = career_mgr.get_ranking_display()
		for entry in ranking:
			var r_row = ColorRect.new()
			r_row.custom_minimum_size = Vector2(740, 40)
			r_row.color = Color(1,1,1, 0.02)
			rankings_vbox.add_child(r_row)
			
			var is_player = (entry.name == career.boxer_name)
			
			if is_player:
				var highlight = ColorRect.new()
				highlight.set_anchors_preset(PRESET_FULL_RECT)
				highlight.color = Color(0.55, 0.75, 0.9, 0.1)
				r_row.add_child(highlight)
			
			var rk = _make_label("#" + str(entry.rank), 16, COLOR_DIAMOND if is_player else Color(0.7,0.7,0.7,1))
			rk.position = Vector2(20, 10)
			r_row.add_child(rk)
			
			var nm = _make_label(entry.name.to_upper(), 16, Color.WHITE)
			nm.position = Vector2(100, 10)
			r_row.add_child(nm)
			
			var ov = _make_label(str(entry.overall), 16, Color(0.8,0.7,0.3,1))
			ov.position = Vector2(650, 10)
			r_row.add_child(ov)
			
			if entry.rank == 1:
				nm.text = "👑 " + nm.text

func _animate_bar(fill: ColorRect, val: float) -> void:
	var max_w = 340.0
	var target = clampf(val / 100.0, 0.0, 1.0) * max_w
	fill.size.x = 0
	var tw = create_tween()
	tw.tween_property(fill, "size:x", target, 0.6).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

func _on_fight_pressed() -> void:
	if is_transitioning: return
	
	# --- Safety checks ---
	if not career_mgr or not career_mgr.career:
		push_warning("CareerMenu: No career loaded. Cannot start fight.")
		return
	
	is_transitioning = true
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("menu_select")
	
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		push_error("CareerMenu: GameManager not found!")
		is_transitioning = false
		return
	
	# --- Resolve player profile ---
	var p_res: BoxerData = null
	var path = career_mgr.career.boxer_data_path if career_mgr.career.boxer_data_path != "" else ""
	if path != "" and ResourceLoader.exists(path):
		p_res = load(path)
	
	# Fallback: find by name in the full ranking roster
	if not p_res and not career_mgr.full_ranking.is_empty():
		for boxer in career_mgr.full_ranking:
			if boxer.boxer_name == career_mgr.career.boxer_name:
				p_res = boxer
				break
	
	# Last resort fallback: first in roster
	if not p_res and not career_mgr.full_ranking.is_empty():
		p_res = career_mgr.full_ranking[0]
	
	if not p_res:
		push_error("CareerMenu: Could not resolve player BoxerData!")
		is_transitioning = false
		return
	
	# --- Resolve opponent ---
	var opp: BoxerData = career_mgr.get_next_opponent()
	if not opp and not career_mgr.full_ranking.is_empty():
		opp = career_mgr.full_ranking[0]
	
	if not opp:
		push_error("CareerMenu: Could not resolve opponent BoxerData!")
		is_transitioning = false
		return
	
	# --- Set GameManager state ---
	gm.player_profile = p_res
	gm.enemy_profile  = opp
	gm.is_career_mode = true
	gm.current_career = career_mgr.career
	
	# --- Transition to Pre-Fight Card ---
	# We go directly — the pre_fight_card scene handles its own cinematic presentation
	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		await cm.fade_in(0.4)
	get_tree().change_scene_to_file("res://scenes/cinematics/pre_fight_card.tscn")

func _go_back() -> void:
	var cm = get_node_or_null("/root/CinematicManager")
	if cm: cm.change_scene("res://scenes/menus/main_menu.tscn")
	else: get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
