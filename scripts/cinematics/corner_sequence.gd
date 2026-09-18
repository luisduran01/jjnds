extends Control

# ============================================================
# CORNER SEQUENCE — Phase 5 Cinematic Polish
# Presentación entre rounds con estadísticas del round
# ============================================================

var is_finished: bool = false
signal corner_sequence_finished

const COACH_TIPS = [
	"Keep your hands up!",
	"Work the body, break him down!",
	"Stay patient. Use your jab!",
	"Don't let him get comfortable!",
	"He's getting tired — press him now!",
	"Protect yourself at all times!",
	"Counter after the block!",
]

func _ready() -> void:
	# Fondo semi-transparente oscuro (sobre la arena)
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.07, 0.93)
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var cm = get_node_or_null("/root/CinematicManager")
	if cm:
		cm.cinematic_skipped.connect(_on_skipped)

func play_sequence(stats: Dictionary) -> void:
	is_finished = false

	var cm = get_node_or_null("/root/CinematicManager")
	if cm: await cm.fade_in(0.4)

	if is_finished: return

	# Construir UI
	_build_corner_ui(stats)

	# Mostrar UI con fade
	if cm: await cm.fade_out(0.4)
	if is_finished: return

	# Esperar (con skip disponible)
	await get_tree().create_timer(5.0).timeout
	if is_finished: return

	_finish_sequence()

func _build_corner_ui(stats: Dictionary) -> void:
	# Tarjeta central
	var card = Control.new()
	card.set_anchors_preset(PRESET_CENTER)
	card.offset_left = -300; card.offset_right = 300
	card.offset_top  = -200; card.offset_bottom = 200
	add_child(card)

	var card_bg = ColorRect.new()
	card_bg.color = Color(0.08, 0.10, 0.15, 0.97)
	card_bg.set_anchors_preset(PRESET_FULL_RECT)
	card_bg.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(card_bg)

	# Borde Diamond
	var border = ColorRect.new()
	border.color = Color(0.55, 0.75, 0.9, 0.3)
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -2; border.offset_top = -2
	border.offset_right = 2; border.offset_bottom = 2
	border.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(border)

	# "ROUND OVER" title
	var title = Label.new()
	title.text = "ROUND OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(PRESET_TOP_WIDE)
	title.offset_top = 22; title.offset_bottom = 58
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.55, 0.75, 0.9, 1))
	card.add_child(title)

	# Separador
	var sep = ColorRect.new()
	sep.color = Color(0.55, 0.75, 0.9, 0.25)
	sep.set_anchors_preset(PRESET_TOP_WIDE)
	sep.offset_top = 64; sep.offset_bottom = 66
	sep.offset_left = 30; sep.offset_right = -30
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	card.add_child(sep)

	# Stats
	var p_thrown  = stats.get("p_thrown", 0)
	var p_landed  = stats.get("p_landed", 0)
	var p_acc     = int((float(p_landed) / max(p_thrown, 1)) * 100.0)

	_add_stat_row(card, "PUNCHES THROWN", str(p_thrown), 85)
	_add_stat_row(card, "PUNCHES LANDED", str(p_landed), 110)
	_add_stat_row(card, "ACCURACY", str(p_acc) + "%", 135)

	# Coach advice
	var tip = COACH_TIPS[randi() % COACH_TIPS.size()]
	var coach_lbl = Label.new()
	coach_lbl.text = "COACH: \"%s\"" % tip
	coach_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_lbl.set_anchors_preset(PRESET_TOP_WIDE)
	coach_lbl.offset_top = 170; coach_lbl.offset_bottom = 220
	coach_lbl.add_theme_font_size_override("font_size", 17)
	coach_lbl.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3, 1))
	coach_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(coach_lbl)

	# Hint skip
	var hint = Label.new()
	hint.text = "[ ENTER / ESC ]  Skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(PRESET_BOTTOM_WIDE)
	hint.offset_top = -35; hint.offset_bottom = -10
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4, 0.7))
	card.add_child(hint)

func _add_stat_row(parent: Control, label_text: String, value_text: String, y: float) -> void:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl.offset_top = y; lbl.offset_bottom = y + 24
	lbl.offset_left = 40; lbl.offset_right = -40
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1))
	parent.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.set_anchors_preset(Control.PRESET_TOP_WIDE)
	val.offset_top = y; val.offset_bottom = y + 24
	val.offset_left = 40; val.offset_right = -40
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 16)
	val.add_theme_color_override("font_color", Color.WHITE)
	parent.add_child(val)

func _on_skipped() -> void:
	if not is_finished:
		_finish_sequence()

func _finish_sequence() -> void:
	is_finished = true
	var cm = get_node_or_null("/root/CinematicManager")
	if cm: await cm.fade_in(0.4)
	corner_sequence_finished.emit()
	queue_free()
