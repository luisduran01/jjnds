extends Control

# Fase F - Saco Pesado (Heavy Bag Training)

var hits: int = 0
var max_hits: int = 30
var time_left: float = 15.0

var is_finished: bool = false
var bag_sprite: Sprite2D
var timer_label: Label
var score_label: Label
var progress_bar: ProgressBar

func _ready() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.2, 0.2, 0.2, 1)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	bag_sprite = Sprite2D.new()
	var tex = load("res://assets/sprites/publico.png")
	if tex:
		bag_sprite.texture = tex
		bag_sprite.region_enabled = true
		bag_sprite.region_rect = Rect2(300, 300, 150, 200) # Heavy bag placeholder
	
	bag_sprite.position = Vector2(640, 360)
	add_child(bag_sprite)
	
	timer_label = Label.new()
	timer_label.text = "15.0"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(PRESET_TOP_WIDE)
	timer_label.position.y = 20
	timer_label.add_theme_font_size_override("font_size", 48)
	add_child(timer_label)
	
	score_label = Label.new()
	score_label.text = "HITS: 0 / " + str(max_hits)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(PRESET_TOP_WIDE)
	score_label.position.y = 90
	score_label.add_theme_font_size_override("font_size", 32)
	add_child(score_label)
	
	progress_bar = ProgressBar.new()
	progress_bar.max_value = max_hits
	progress_bar.set_anchors_preset(PRESET_BOTTOM_WIDE)
	progress_bar.position.y = -50
	progress_bar.custom_minimum_size = Vector2(0, 40)
	add_child(progress_bar)
	
	var cm = get_node_or_null("/root/CinematicManager")
	if cm: await cm.show_card("HEAVY BAG", "HIT THE BAG 30 TIMES", "TRAINING", 2.0, false)
	
	set_process(true)
	set_process_input(true)

func _process(delta: float) -> void:
	if is_finished: return
	
	time_left -= delta
	if time_left <= 0:
		time_left = 0
		_finish_training()
	
	timer_label.text = "%.1f" % time_left

func _input(event: InputEvent) -> void:
	if is_finished: return
	
	if event.is_action_pressed("attack") or event.is_action_pressed("ui_accept"):
		_hit_bag()

func _hit_bag() -> void:
	hits += 1
	progress_bar.value = hits
	score_label.text = "HITS: " + str(hits) + " / " + str(max_hits)
	
	var sm = get_node_or_null("/root/SoundManager")
	if sm: sm.play("punch_jab")
	
	# Visual feedback
	var tw = create_tween()
	bag_sprite.rotation_degrees = 15.0
	tw.tween_property(bag_sprite, "rotation_degrees", 0.0, 0.1)
	
	if hits >= max_hits:
		_finish_training()

func _finish_training() -> void:
	is_finished = true
	set_process(false)
	set_process_input(false)
	
	var success = hits >= max_hits
	var cm = get_node_or_null("/root/CinematicManager")
	
	if success:
		if cm: await cm.show_card("SUCCESS!", "+5 POWER", "", 2.0, false)
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.current_career:
			gm.current_career.temp_power_boost += 5
			var sm = load("res://scripts/career/career_manager.gd")
			if sm:
				var m = sm.new()
				m.career = gm.current_career
				m.save_career()
	else:
		if cm: await cm.show_card("FAILED", "NOT ENOUGH HITS", "", 2.0, false)
		
	if cm:
		cm.change_scene("res://scenes/training/training_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/training/training_menu.tscn")
