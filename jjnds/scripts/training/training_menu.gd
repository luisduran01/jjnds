extends Control

const SAVE_PATH = "user://career_save.tres"

const TRAINING_COSTS = {
	"power": 500,
	"speed": 400,
	"stamina": 300,
	"defense": 450
}

const TRAINING_GAINS = {
	"power": 5,
	"speed": 5,
	"stamina": 10.0,
	"defense": 5
}

var career: CareerData = null
var money_label: Label
var stats_labels: Dictionary = {}
var player_sprite: AnimatedSprite2D

const COLOR_DIAMOND = Color(0.55, 0.75, 0.9, 1)

func _ready() -> void:
	career = CareerData.load_career(SAVE_PATH)
	if career == null:
		push_warning("No career save found, returning to main menu.")
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
		return
		
	# Fondo del gimnasio
	var bg = TextureRect.new()
	bg.texture = load("res://assets/sprites/gimnasio.png")
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	# Capa de oscurecimiento suave
	var overlay = ColorRect.new()
	overlay.color = Color(0.05, 0.05, 0.1, 0.4)
	overlay.set_anchors_preset(PRESET_FULL_RECT)
	overlay.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(overlay)
	
	# Jugador animado
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.player_profile != null:
		var p_scene = load("res://assets/player.tscn")
		if p_scene:
			var p_node = p_scene.instantiate()
			player_sprite = p_node.get_node("AnimatedSprite2D").duplicate()
			p_node.queue_free()
	
	if player_sprite == null:
		player_sprite = AnimatedSprite2D.new()
	
	player_sprite.position = Vector2(640, 480)
	player_sprite.scale = Vector2(1.5, 1.5)
	if player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("idle"):
		player_sprite.play("idle")
	add_child(player_sprite)
	
	_build_ui()
	_update_labels()

func _build_ui() -> void:
	# Header
	var header = ColorRect.new()
	header.color = Color(0.05, 0.05, 0.1, 0.85)
	header.set_anchors_preset(PRESET_TOP_WIDE)
	header.custom_minimum_size = Vector2(0, 80)
	add_child(header)
	
	var title = Label.new()
	title.text = "TRAINING CAMP"
	title.set_anchors_preset(PRESET_TOP_LEFT)
	title.offset_left = 40; title.offset_top = 20
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", COLOR_DIAMOND)
	header.add_child(title)
	
	money_label = Label.new()
	money_label.text = "$0"
	money_label.set_anchors_preset(PRESET_TOP_RIGHT)
	money_label.offset_left = -250; money_label.offset_top = 30
	money_label.offset_right = -40; money_label.offset_bottom = 60
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.add_theme_font_size_override("font_size", 24)
	money_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1))
	header.add_child(money_label)
	
	# Current Stats Card
	var stats_card = _make_card(Vector2(40, 120), Vector2(300, 240))
	add_child(stats_card)
	
	var sl = Label.new()
	sl.text = "CURRENT STATS"
	sl.position = Vector2(20, 15)
	sl.add_theme_color_override("font_color", Color(0.7,0.7,0.7,1))
	stats_card.add_child(sl)
	
	var y = 50
	for stat in ["power", "speed", "stamina", "defense"]:
		var lbl_name = Label.new()
		lbl_name.text = stat.to_upper()
		lbl_name.position = Vector2(20, y)
		lbl_name.add_theme_font_size_override("font_size", 14)
		stats_card.add_child(lbl_name)
		
		var lbl_val = Label.new()
		lbl_val.text = "0"
		lbl_val.position = Vector2(230, y)
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl_val.add_theme_font_size_override("font_size", 14)
		lbl_val.add_theme_color_override("font_color", COLOR_DIAMOND)
		stats_card.add_child(lbl_val)
		stats_labels[stat] = lbl_val
		
		y += 40
		
	# Training Options
	var options_vbox = VBoxContainer.new()
	options_vbox.set_anchors_preset(PRESET_CENTER_RIGHT)
	options_vbox.offset_left = -380; options_vbox.offset_top = -150
	options_vbox.offset_right = -40; options_vbox.offset_bottom = 150
	options_vbox.add_theme_constant_override("separation", 20)
	add_child(options_vbox)
	
	_add_training_button(options_vbox, "HEAVY BAG", "POWER", TRAINING_GAINS.power, TRAINING_COSTS.power, "power")
	_add_training_button(options_vbox, "SPEED BAG", "SPEED", TRAINING_GAINS.speed, TRAINING_COSTS.speed, "speed")
	_add_training_button(options_vbox, "ROADWORK", "STAMINA", TRAINING_GAINS.stamina, TRAINING_COSTS.stamina, "stamina")
	_add_training_button(options_vbox, "SPARRING", "DEFENSE", TRAINING_GAINS.defense, TRAINING_COSTS.defense, "defense")
	
	var btn_back = Button.new()
	btn_back.text = "RETURN TO HUB"
	btn_back.set_anchors_preset(PRESET_BOTTOM_LEFT)
	btn_back.offset_left = 40; btn_back.offset_top = -80
	btn_back.offset_right = 240; btn_back.offset_bottom = -40
	btn_back.add_theme_font_size_override("font_size", 16)
	btn_back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/career/career_menu.tscn"))
	add_child(btn_back)

func _make_card(pos: Vector2, size: Vector2) -> ColorRect:
	var cr = ColorRect.new()
	cr.color = Color(0.05, 0.05, 0.1, 0.85)
	cr.position = pos
	cr.size = size
	var border = ColorRect.new()
	border.color = COLOR_DIAMOND
	border.color.a = 0.3
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -1; border.offset_top = -1
	border.offset_right = 1; border.offset_bottom = 1
	border.mouse_filter = MOUSE_FILTER_IGNORE
	cr.add_child(border)
	return cr

func _add_training_button(parent: Control, title: String, stat_name: String, gain: float, cost: int, stat_key: String) -> void:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(340, 70)
	
	var name_lbl = Label.new()
	name_lbl.text = title
	name_lbl.position = Vector2(20, 15)
	name_lbl.add_theme_font_size_override("font_size", 18)
	btn.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = "+%d %s" % [gain, stat_name]
	desc_lbl.position = Vector2(20, 40)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", COLOR_DIAMOND)
	btn.add_child(desc_lbl)
	
	var cost_lbl = Label.new()
	cost_lbl.text = "$%d" % cost
	cost_lbl.set_anchors_preset(PRESET_TOP_RIGHT)
	cost_lbl.offset_left = -100; cost_lbl.offset_top = 25
	cost_lbl.offset_right = -20; cost_lbl.offset_bottom = 50
	cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3, 1))
	btn.add_child(cost_lbl)
	
	btn.pressed.connect(func(): _on_train_pressed(stat_key, cost, gain))
	parent.add_child(btn)

func _update_labels() -> void:
	if not career: return
	money_label.text = "$%d" % career.money
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.player_profile:
		stats_labels["power"].text = str(gm.player_profile.jab_power) # Simplified proxy for power
		stats_labels["speed"].text = str(1.0 / max(gm.player_profile.jab_cooldown, 0.1)).pad_decimals(1)
		stats_labels["stamina"].text = str(gm.player_profile.stamina_max)
		stats_labels["defense"].text = str(gm.player_profile.health) # Proxy for defense/durability

func _on_train_pressed(stat_type: String, cost: int, gain: float) -> void:
	if career.money >= cost:
		career.money -= cost
		
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.player_profile:
			# Apply boost directly to the current profile
			if stat_type == "power":
				gm.player_profile.jab_power += gain
				gm.player_profile.cross_power += gain
				gm.player_profile.hook_power += gain
				gm.player_profile.uppercut_power += gain
			elif stat_type == "speed":
				gm.player_profile.jab_cooldown *= 0.95
				gm.player_profile.cross_cooldown *= 0.95
				gm.player_profile.hook_cooldown *= 0.95
			elif stat_type == "stamina":
				gm.player_profile.stamina_max += gain
			elif stat_type == "defense":
				gm.player_profile.health += int(gain)
				
			ResourceSaver.save(gm.player_profile, gm.player_profile.resource_path)
			
		career.save_career(SAVE_PATH)
		
		# Feedback
		if player_sprite and player_sprite.sprite_frames and player_sprite.sprite_frames.has_animation("punch"):
			player_sprite.play("punch")
			await get_tree().create_timer(0.3).timeout
			player_sprite.play("idle")
			
		var sm = get_node_or_null("/root/SoundManager")
		if sm: sm.play("ui_select")
		
		_update_labels()
	else:
		print("Not enough money!")
		var sm = get_node_or_null("/root/SoundManager")
		if sm: sm.play("ui_error")
