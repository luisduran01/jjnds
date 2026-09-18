extends Control

# Componentes Visuales
@onready var parallax_bg = $Background/ParallaxLayer
@onready var boxer_sprite = $Background/MenuFighter
@onready var title_boxing = $UI/Header/TitleBoxing
@onready var title_champ = $UI/Header/TitleChamp
@onready var btn_container = $UI/MenuPanel
@onready var desc_label = $UI/DescriptionPanel/DescLabel
@onready var profile_label = $UI/Footer/ProfileLabel
@onready var fight_card = $UI/FighterInfo/FightCard
@onready var champion_belt = $Background/ChampionBelt

# Estado
var is_transitioning: bool = false
var original_btn_positions: Dictionary = {}

# Textos de descripción
const DESCRIPTIONS = {
	"btn_career": "Create your legacy.\nTrain, fight and become champion.",
	"btn_quick": "Choose your fighter and step into the ring.",
	"btn_training": "Improve your skills and master your combinations.",
	"btn_roster": "Explore the boxing roster.",
	"btn_options": "Audio, controls and game settings.",
	"btn_exit": "Leave the game."
}

func _ready() -> void:
	# Configurar botones
	var index = 0
	for btn in btn_container.get_children():
		if btn is Button:
			original_btn_positions[btn] = btn.position
			btn.mouse_entered.connect(_on_btn_focus.bind(btn))
			btn.focus_entered.connect(_on_btn_focus.bind(btn))
			btn.mouse_exited.connect(_on_btn_unfocus.bind(btn))
			btn.focus_exited.connect(_on_btn_unfocus.bind(btn))
			btn.pressed.connect(_on_btn_pressed.bind(btn))
			
			# Configurar focus neighbors
			var prev_btn = btn_container.get_child(max(0, index - 1))
			var next_btn = btn_container.get_child(min(btn_container.get_child_count() - 1, index + 1))
			btn.focus_neighbor_top = prev_btn.get_path()
			btn.focus_neighbor_bottom = next_btn.get_path()
			index += 1
			
			# Sidebar placeholder
			var sidebar = ColorRect.new()
			sidebar.name = "Sidebar"
			sidebar.color = Color(0.85, 0.75, 0.3, 1) # Dorado
			sidebar.set_anchors_preset(PRESET_LEFT_WIDE)
			sidebar.custom_minimum_size = Vector2(6, 0)
			sidebar.position.x = -15
			sidebar.modulate.a = 0
			btn.add_child(sidebar)
	
	# Deshabilitar botones no implementados temporalmente (sin causar errores)
	$UI/MenuPanel/btn_training.disabled = true
	$UI/MenuPanel/btn_roster.disabled = true
	$UI/MenuPanel/btn_options.disabled = true
	
	_load_dynamic_data()
	_play_entrance_animation()
	
	# Focus initial
	if btn_container.get_child_count() > 0:
		btn_container.get_child(0).grab_focus()

func _process(_delta: float) -> void:
	if is_transitioning: return
	
	# Parallax muy sutil
	var mouse_pos = get_global_mouse_position()
	var screen_center = get_viewport_rect().size / 2.0
	var offset = (mouse_pos - screen_center) / screen_center
	
	if parallax_bg:
		parallax_bg.position = lerp(parallax_bg.position, offset * -15.0, 0.05)
	if boxer_sprite:
		boxer_sprite.position = lerp(boxer_sprite.position, Vector2(850, 360) + offset * -5.0, 0.05)

# ---------------------------------------------------------
# CARGA DE DATOS
# ---------------------------------------------------------
func _load_dynamic_data() -> void:
	var cm = get_node_or_null("/root/CareerManager")
	var gm = get_node_or_null("/root/GameManager")
	
	champion_belt.hide()
	
	if cm and cm.career and cm.career.wins + cm.career.losses + cm.career.draws > 0:
		var c = cm.career
		profile_label.text = "PLAYER\nALONSO\nCAREER %d-%d-%d\nRANK #%d" % [c.wins, c.losses, c.draws, c.rank]
		
		if gm and gm.player_profile:
			fight_card.text = "CONTINUE CAREER\n\nALONSO\nOVR %d" % ((c.temp_power_boost + c.temp_speed_boost + c.temp_stamina_boost + c.temp_defense_boost)/4 + 65)
		else:
			fight_card.text = "CONTINUE CAREER\n\nALONSO\nOVR 68"
			
		if c.rank == 1: # Champion placeholder logic
			champion_belt.show()
	else:
		profile_label.text = "PLAYER\nALONSO\nNEW CAREER"
		fight_card.text = "BUILD YOUR LEGACY\n\n0-0-0\nBEGIN YOUR JOURNEY"


# ---------------------------------------------------------
# ANIMACIONES DE INTERFAZ
# ---------------------------------------------------------
func _on_btn_focus(btn: Button) -> void:
	if is_transitioning: return
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("menu_move") # Asumimos que existe o lo ignorará silenciosamente
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "position:x", original_btn_positions[btn].x + 20.0, 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "modulate", Color(1.2, 1.2, 1.2, 1), 0.15)
	
	var sidebar = btn.get_node_or_null("Sidebar")
	if sidebar:
		tw.tween_property(sidebar, "modulate:a", 1.0, 0.15)
		
	desc_label.text = DESCRIPTIONS.get(btn.name, "")

func _on_btn_unfocus(btn: Button) -> void:
	if is_transitioning: return
	
	var tw = create_tween().set_parallel(true)
	tw.tween_property(btn, "position:x", original_btn_positions[btn].x, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.2)
	
	var sidebar = btn.get_node_or_null("Sidebar")
	if sidebar:
		tw.tween_property(sidebar, "modulate:a", 0.0, 0.2)

func _play_entrance_animation() -> void:
	# Estado inicial invisible
	title_boxing.modulate.a = 0
	title_champ.modulate.a = 0
	boxer_sprite.modulate.a = 0
	btn_container.modulate.a = 0
	
	title_boxing.position.y -= 30
	boxer_sprite.position.x += 50
	btn_container.position.x -= 50
	
	var tw = create_tween()
	# Fondo y Boxeador
	tw.tween_property(boxer_sprite, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(boxer_sprite, "position:x", 850.0, 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	
	# Titulos
	tw.tween_property(title_boxing, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(title_boxing, "position:y", title_boxing.position.y + 30, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_champ, "modulate:a", 1.0, 0.3)
	
	# Menu
	tw.tween_property(btn_container, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(btn_container, "position:x", btn_container.position.x + 50, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------
# LÓGICA DE BOTONES (Original conservada)
# ---------------------------------------------------------
func _on_btn_pressed(btn: Button) -> void:
	if is_transitioning: return
	is_transitioning = true
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("menu_select")
	
	# Pequeño flash del botón
	var tw = create_tween()
	tw.tween_property(btn, "modulate", Color(2, 2, 2, 1), 0.1)
	tw.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.1)
	
	var cm = get_node_or_null("/root/CinematicManager")
	var tm = get_node_or_null("/root/TransitionManager")
	
	match btn.name:
		"btn_career":
			if cm: cm.change_scene("res://scenes/career/career_menu.tscn")
			elif tm: tm.change_scene("res://scenes/career/career_menu.tscn")
			else: get_tree().change_scene_to_file("res://scenes/career/career_menu.tscn")
		"btn_quick":
			if cm: cm.change_scene("res://scenes/menus/character_select.tscn")
			elif tm: tm.change_scene("res://scenes/menus/character_select.tscn")
			else: get_tree().change_scene_to_file("res://scenes/menus/character_select.tscn")
		"btn_exit":
			if cm: 
				await cm.fade_out(0.5)
				get_tree().quit()
			else:
				get_tree().quit()
