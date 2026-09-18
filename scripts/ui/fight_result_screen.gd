extends Control

# Post Fight Results Screen
# Called by main.gd after a fight ends

var winner_label: Label
var method_label: Label
var stats_container: VBoxContainer

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark translucent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.85)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	
	var center = VBoxContainer.new()
	center.set_anchors_preset(PRESET_CENTER)
	center.custom_minimum_size = Vector2(500, 0)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)
	
	var title = Label.new()
	title.text = "FIGHT RESULT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	center.add_child(title)
	
	var sep1 = HSeparator.new()
	center.add_child(sep1)
	
	winner_label = Label.new()
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 26)
	center.add_child(winner_label)
	
	method_label = Label.new()
	method_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	method_label.add_theme_font_size_override("font_size", 18)
	center.add_child(method_label)
	
	var sep2 = HSeparator.new()
	center.add_child(sep2)
	
	stats_container = VBoxContainer.new()
	center.add_child(stats_container)
	
	var sep3 = HSeparator.new()
	center.add_child(sep3)
	
	var btn_rematch = Button.new()
	btn_rematch.text = "REMATCH"
	btn_rematch.pressed.connect(_on_rematch)
	center.add_child(btn_rematch)
	
	var btn_menu = Button.new()
	btn_menu.text = "MAIN MENU"
	btn_menu.pressed.connect(_on_main_menu)
	center.add_child(btn_menu)

func show_result(winner: String, method: String, stats: Dictionary) -> void:
	winner_label.text = winner.to_upper() + " WINS!"
	method_label.text = "by " + method
	
	for child in stats_container.get_children():
		child.queue_free()
	
	var header = Label.new()
	header.text = "FIGHT STATISTICS"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_container.add_child(header)
	
	var cols = HBoxContainer.new()
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	stats_container.add_child(cols)
	
	var player_col = VBoxContainer.new()
	player_col.custom_minimum_size = Vector2(180, 0)
	cols.add_child(player_col)
	
	var label_col = VBoxContainer.new()
	label_col.custom_minimum_size = Vector2(140, 0)
	cols.add_child(label_col)
	
	var enemy_col = VBoxContainer.new()
	enemy_col.custom_minimum_size = Vector2(180, 0)
	cols.add_child(enemy_col)
	
	_add_stat_row(player_col, label_col, enemy_col,
		str(stats.get("p_thrown", 0)),
		"Punches Thrown",
		str(stats.get("e_thrown", 0)))
		
	_add_stat_row(player_col, label_col, enemy_col,
		str(stats.get("p_landed", 0)),
		"Punches Landed",
		str(stats.get("e_landed", 0)))
	
	var p_acc = 0
	if stats.get("p_thrown", 0) > 0:
		p_acc = int(float(stats.get("p_landed", 0)) / float(stats.get("p_thrown", 0)) * 100)
	var e_acc = 0
	if stats.get("e_thrown", 0) > 0:
		e_acc = int(float(stats.get("e_landed", 0)) / float(stats.get("e_thrown", 0)) * 100)
	
	_add_stat_row(player_col, label_col, enemy_col,
		str(p_acc) + "%",
		"Accuracy",
		str(e_acc) + "%")
		
	_add_stat_row(player_col, label_col, enemy_col,
		str(stats.get("p_knockdowns", 0)),
		"Knockdowns",
		str(stats.get("e_knockdowns", 0)))
	
	show()
	set_process_input(true)

func _add_stat_row(left: VBoxContainer, center: VBoxContainer, right: VBoxContainer, left_val: String, center_label: String, right_val: String) -> void:
	var lv = Label.new()
	lv.text = left_val
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(lv)
	
	var cl = Label.new()
	cl.text = center_label
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(cl)
	
	var rv = Label.new()
	rv.text = right_val
	rv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.add_child(rv)

func _on_rematch() -> void:
	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		cm.change_scene("res://assets/main.tscn")
	else:
		get_tree().change_scene_to_file("res://assets/main.tscn")

func _on_main_menu() -> void:
	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		cm.change_scene("res://scenes/menus/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
