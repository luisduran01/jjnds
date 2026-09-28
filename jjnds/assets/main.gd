extends Node2D


@onready var player = $Player
@onready var enemy = $Enemy

@onready var player_health_bar: ProgressBar = $HUD/PlayerHealthBar
@onready var enemy_health_bar: ProgressBar = $HUD/EnemyHealthBar
@onready var player_stamina_bar: ProgressBar = $HUD/PlayerStaminaBar
@onready var enemy_stamina_bar: ProgressBar = $HUD/EnemyStaminaBar

@onready var round_label: Label = $HUD/RoundLabel
@onready var timer_label: Label = $HUD/TimerLabel
@onready var player_name_label: Label = $HUD/PlayerName
@onready var enemy_name_label: Label  = $HUD/EnemyName

var _low_health_vignette: ColorRect
var _camera_zoom_target: Vector2 = Vector2(1.05, 1.05)
var _camera: Camera2D

var round_manager: Node
var fight_manager: FightManager
var result_screen: Control
var fight_ended: bool = false
var crowd_manager: Node
var combat_feel: Node

# Damage trail bars (lag behind real HP)
var player_hp_trail: ProgressBar
var enemy_hp_trail: ProgressBar
var _player_trail_target: float = 100.0
var _enemy_trail_target: float = 100.0

var player_shadow: Polygon2D
var enemy_shadow: Polygon2D


func _process(delta: float) -> void:
	# Smooth damage trail bars toward target values
	if player_hp_trail:
		player_hp_trail.value = lerpf(player_hp_trail.value, _player_trail_target, delta * 3.5)
	if enemy_hp_trail:
		enemy_hp_trail.value = lerpf(enemy_hp_trail.value, _enemy_trail_target, delta * 3.5)
		
	# Update shadows to stay on the ground
	if player_shadow and player:
		player_shadow.position = Vector2(player.position.x, player.get("ground_y") if player.has_method("get") and player.get("ground_y") != null else player.position.y)
		var diff = player.get("ground_y") - player.position.y if player.has_method("get") and player.get("ground_y") != null else 0.0
		var sc = clampf(1.0 - (diff / 200.0), 0.5, 1.0)
		player_shadow.scale = Vector2(sc, sc)
		
	if enemy_shadow and enemy:
		enemy_shadow.position = Vector2(enemy.position.x, enemy.position.y)
		
	# Low-health vignette
	if _low_health_vignette and player:
		var hp_ratio = float(player.health) / float(max(player.max_health, 1))
		var target_a = 0.0
		if hp_ratio < 0.25:
			target_a = (0.25 - hp_ratio) / 0.25 * 0.55
		_low_health_vignette.modulate.a = lerpf(_low_health_vignette.modulate.a, target_a, delta * 4.0)
	
	# Dynamic camera zoom based on fighter distance
	if _camera and player and enemy:
		var dist = abs(player.position.x - enemy.position.x)
		var zoom_val = clampf(remap(dist, 150.0, 500.0, 1.08, 0.98), 0.95, 1.12)
		_camera_zoom_target = Vector2(zoom_val, zoom_val)
		_camera.zoom = _camera.zoom.lerp(_camera_zoom_target, delta * 2.5)

func _ready() -> void:
	round_manager = load("res://scripts/managers/round_manager.gd").new()
	add_child(round_manager)
	
	fight_manager = load("res://scripts/managers/fight_manager.gd").new()
	add_child(fight_manager)

	_apply_visual_depth()

	# --- CombatFeel system ---
	combat_feel = load("res://scripts/managers/combat_feel.gd").new()
	add_child(combat_feel)
	var camera = get_node_or_null("Camera2D")
	# Combo counter label (created dynamically on HUD)
	var hud_node = get_node_or_null("HUD")
	var combo_lbl: Label = null
	if hud_node:
		combo_lbl = Label.new()
		combo_lbl.name = "ComboLabel"
		combo_lbl.text = ""
		combo_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		combo_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
		combo_lbl.position.y = 80
		combo_lbl.add_theme_font_size_override("font_size", 26)
		combo_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
		combo_lbl.modulate.a = 0.0
		hud_node.add_child(combo_lbl)
		# Create damage trail bars under the real health bars
		var p_trail = ProgressBar.new()
		p_trail.max_value = 100
		p_trail.value = 100
		p_trail.show_percentage = false
		p_trail.modulate = Color(0.9, 0.6, 0.1, 0.7)
		if player_health_bar:
			player_health_bar.get_parent().add_child_below_node(player_health_bar, p_trail)
			p_trail.size = player_health_bar.size
			p_trail.position = player_health_bar.position
		player_hp_trail = p_trail

		var e_trail = ProgressBar.new()
		e_trail.max_value = 100
		e_trail.value = 100
		e_trail.show_percentage = false
		e_trail.modulate = Color(0.9, 0.6, 0.1, 0.7)
		if enemy_health_bar:
			enemy_health_bar.get_parent().add_child_below_node(enemy_health_bar, e_trail)
			e_trail.size = enemy_health_bar.size
			e_trail.position = enemy_health_bar.position
		enemy_hp_trail = e_trail

	combat_feel.setup(camera, combo_lbl)

	# Load profiles from GameManager (set by menus)
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.player_profile != null:
		player.boxer_profile = gm.player_profile
		player._apply_boxer_profile()
	if gm and gm.enemy_profile != null:
		enemy.boxer_profile = gm.enemy_profile
		enemy._apply_boxer_profile()

	player_health_bar.max_value = player.max_health
	player_health_bar.value = player.health
	player_stamina_bar.max_value = player.max_stamina
	player_stamina_bar.value = player.stamina
	# Sync trail bars max
	if player_hp_trail:
		player_hp_trail.max_value = player.max_health
		player_hp_trail.value = player.max_health
	_player_trail_target = float(player.max_health)

	enemy_health_bar.max_value = enemy.max_health
	enemy_health_bar.value = enemy.health
	enemy_stamina_bar.max_value = enemy.max_stamina
	enemy_stamina_bar.value = enemy.stamina
	if enemy_hp_trail:
		enemy_hp_trail.max_value = enemy.max_health
		enemy_hp_trail.value = enemy.max_health
	_enemy_trail_target = float(enemy.max_health)
	
	# Update HUD names from profiles
	if player_name_label and player.boxer_profile:
		player_name_label.text = player.boxer_profile.boxer_name.to_upper()
	if enemy_name_label and enemy.boxer_profile:
		enemy_name_label.text = enemy.boxer_profile.boxer_name.to_upper()

	player.health_changed.connect(_on_player_health_changed)
	player.stamina_changed.connect(_on_player_stamina_changed)
	enemy.health_changed.connect(_on_enemy_health_changed)
	enemy.stamina_changed.connect(_on_enemy_stamina_changed)

	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	
	player.knocked_down.connect(_on_player_knocked_down)
	enemy.knocked_down.connect(_on_enemy_knocked_down)
	player.punch_thrown.connect(func(): fight_manager.record_punch_thrown(true))
	player.punch_landed.connect(func(): 
		fight_manager.record_punch_landed(true)
		if crowd_manager and randf() > 0.7: crowd_manager.trigger_reaction("strong_hit")
		if combat_feel: 
			var pt = player.get("last_punch_type")
			if pt == null: pt = "jab"
			combat_feel.register_hit(pt)
			combat_feel.trigger_hit_stop(pt)
			combat_feel.trigger_flash(enemy.sprite)
			
			var sm = get_node_or_null("/root/SoundManager")
			if sm and sm.has_method("play"):
				var sound = "punch_" + pt
				if pt == "body": sound = "punch_hook"
				if pt == "uppercut": sound = "punch_cross"
				sm.play(sound, 0.0, true)
	)
	enemy.punch_thrown.connect(func(): fight_manager.record_punch_thrown(false))
	enemy.punch_landed.connect(func(): 
		fight_manager.record_punch_landed(false)
		if crowd_manager and randf() > 0.7: crowd_manager.trigger_reaction("strong_hit")
		if combat_feel:
			var pt = enemy.get("last_punch_type")
			if pt == null: pt = "jab"
			combat_feel.trigger_shake(pt)
			combat_feel.trigger_hit_stop(pt)
			combat_feel.trigger_flash(player.sprite)
			
			var sm = get_node_or_null("/root/SoundManager")
			if sm and sm.has_method("play"):
				var sound = "punch_" + pt
				if pt == "body": sound = "punch_hook"
				if pt == "uppercut": sound = "punch_cross"
				sm.play(sound, 0.0, true)
	)
	
	round_manager.round_started.connect(_on_round_started)
	round_manager.round_ended.connect(_on_round_ended)
	round_manager.time_updated.connect(_on_time_updated)
	round_manager.rest_time_updated.connect(_on_rest_time_updated)
	round_manager.fight_ended_by_decision.connect(_on_fight_ended_by_decision)
	
	fight_manager.fight_finished.connect(_on_fight_finished)
	
	round_manager.start_fight()
	fight_manager.start_fight()

	# Load result screen
	var rs_scene = load("res://scenes/cinematics/fight_conclusion.tscn")
	if rs_scene:
		result_screen = rs_scene.instantiate()
		result_screen.hide()
		add_child(result_screen)
	
	# Load crowd manager
	var cm_script = load("res://scripts/arena/crowd_manager.gd")
	if cm_script:
		crowd_manager = cm_script.new()
		# Add crowd manager behind everything (z-index)
		crowd_manager.z_index = -5
		add_child(crowd_manager)
		
	# Fade in from black
	var tm = get_node_or_null("/root/TransitionManager")
	if tm:
		await tm.fade_out(0.5)
		
	var sm = get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("play_ambience"):
		sm.play_ambience("ambience_arena")

func _on_round_started(round_number: int) -> void:
	round_label.text = "ROUND " + str(round_number)
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("round_bell")
	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		var top_text  = "FIGHT NIGHT" if round_number == 1 else "BOXING"
		var main_text = "ROUND %d" % round_number
		var sub_text  = "FIGHT!" if round_number == 1 else "BEGIN!"
		await cm.show_card(main_text, sub_text, top_text, 1.6, false)
	player.can_attack = true
	enemy.can_attack = true
	
func _on_round_ended(_round_number: int) -> void:
	round_label.text = "REST"
	player.can_attack = false
	enemy.can_attack = false
	fight_manager.score_round_end()
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("round_bell")
	if crowd_manager: crowd_manager.trigger_reaction("round_end")
	
	if _round_number < round_manager.max_rounds:
		var cs_scene = load("res://scenes/cinematics/corner_sequence.tscn")
		if cs_scene:
			var cs = cs_scene.instantiate()
			add_child(cs)
			cs.play_sequence({
				"p_thrown": fight_manager.p_punches_thrown,
				"p_landed": fight_manager.p_punches_landed
			})
	
func _on_time_updated(time_left: float) -> void:
	var mins = int(time_left) / 60
	var secs = int(time_left) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	# Warning: last 10 seconds turn red and slightly larger
	if time_left <= 10.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2, 1.0))
		timer_label.add_theme_font_size_override("font_size", 34)
	else:
		timer_label.add_theme_color_override("font_color", Color(0.91, 0.97, 1.0, 1.0))
		timer_label.add_theme_font_size_override("font_size", 30)
	
func _on_rest_time_updated(time_left: float) -> void:
	timer_label.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9, 1.0))
	timer_label.add_theme_font_size_override("font_size", 30)
	timer_label.text = "REST  %02d" % [int(time_left)]

func _on_fight_ended_by_decision() -> void:
	fight_manager.evaluate_decision()
	
func _on_fight_finished(winner: String, method: String) -> void:
	if fight_ended:
		return
	fight_ended = true
	round_manager.is_fighting = false
	round_manager.is_resting = false
	player.can_attack = false
	enemy.can_attack = false
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("ko_bell")
	
	# Extra big shake on KO/TKO
	if combat_feel and (method.contains("KO") or method.contains("TKO")):
		combat_feel.trigger_shake("ko")
	
	if crowd_manager and (method.contains("KO") or method.contains("TKO")):
		crowd_manager.trigger_reaction("ko")
	
	var player_won = winner == "Player"
	_report_fight_result(player_won, method.contains("KO") or method.contains("TKO"))
	await get_tree().create_timer(2.5).timeout
	if result_screen:
		result_screen.show_result(winner, method, {
			"p_thrown": fight_manager.p_punches_thrown,
			"p_landed": fight_manager.p_punches_landed,
			"p_knockdowns": fight_manager.p_knockdowns,
			"e_thrown": fight_manager.e_punches_thrown,
			"e_landed": fight_manager.e_punches_landed,
			"e_knockdowns": fight_manager.e_knockdowns,
		})


func _on_player_health_changed(health: int) -> void:
	player_health_bar.value = health
	# Trail follows with delay
	_player_trail_target = float(health)


func _on_enemy_health_changed(health: int) -> void:
	enemy_health_bar.value = health
	_enemy_trail_target = float(health)


func _on_player_stamina_changed(stamina: float) -> void:
	player_stamina_bar.value = stamina


func _on_enemy_stamina_changed(stamina: float) -> void:
	enemy_stamina_bar.value = stamina


func _on_player_died() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("ko_bell")
	_report_fight_result(false, false)


func _on_enemy_died() -> void:
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("ko_bell")
	_report_fight_result(true, true)


func _on_player_knocked_down() -> void:
	fight_manager.record_knockdown(true)
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("knockdown")
	if crowd_manager: crowd_manager.trigger_reaction("knockdown")

func _on_enemy_knocked_down() -> void:
	fight_manager.record_knockdown(false)
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("knockdown")
	if crowd_manager: crowd_manager.trigger_reaction("knockdown")

func _on_fight_result_decision(player_won: bool) -> void:
	_report_fight_result(player_won, false)

func _report_fight_result(player_won: bool, was_ko: bool) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.is_career_mode and gm.current_career != null:
		# Find career manager and report
		var cm_script = load("res://scripts/career/career_manager.gd")
		if cm_script:
			var cm = cm_script.new()
			cm.career = gm.current_career
			cm.on_fight_result(player_won, was_ko)

func _apply_visual_depth() -> void:
	# 1. Global lighting tint (Diamond Blue style)
	var cm = CanvasModulate.new()
	cm.color = Color(0.85, 0.90, 0.98, 1.0) # Cold subtle blue
	add_child(cm)
	
	# 2. Add dynamic shadows
	player_shadow = _create_shadow_poly()
	enemy_shadow = _create_shadow_poly()
	add_child(player_shadow)
	add_child(enemy_shadow)
	
	# 3. Enhance Camera2D
	var cam = get_node_or_null("Camera2D")
	if cam:
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.zoom = Vector2(1.05, 1.05)
	_camera = cam
	
	# Low-health vignette overlay
	var hud = get_node_or_null("HUD")
	if hud:
		_low_health_vignette = ColorRect.new()
		_low_health_vignette.color = Color(0.7, 0.05, 0.05, 0.0)
		_low_health_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
		_low_health_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_low_health_vignette.modulate.a = 0.0
		hud.add_child(_low_health_vignette)

func _create_shadow_poly() -> Polygon2D:
	var shadow = Polygon2D.new()
	shadow.color = Color(0, 0, 0, 0.45)
	var pts = PackedVector2Array()
	var w = 48.0
	var h = 14.0
	for i in range(32):
		var ang = i * PI * 2.0 / 32.0
		pts.append(Vector2(cos(ang) * w, sin(ang) * h))
	shadow.polygon = pts
	shadow.z_index = -2 # Behind fighters but in front of background
	return shadow
