extends Control
# HUD de esquina entre rounds — Corner Club
# Aparece durante Phase.REST y permite elegir tratamiento

var fight       # fight_director
var injury_p    # injury_system del jugador
var momentum    # momentum_system

var _panel: PanelContainer
var _round_lbl: Label
var _time_lbl: Label
var _tip_lbl: Label
var _stats_lbl: Label
var _injury_lbl: Label
var _buttons: Array = []
var _chosen: bool = false

const TREATMENTS = [
	{"id": "reduce_swelling", "icon": "🧊", "label": "Reducir hinchazón"},
	{"id": "recover_stamina",  "icon": "💧", "label": "Recuperar stamina"},
	{"id": "treat_cut",        "icon": "🩹", "label": "Tratar corte"},
	{"id": "change_strategy",  "icon": "🧠", "label": "Cambiar estrategia"},
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_panel.offset_left  = -340
	_panel.offset_right =  340
	_panel.offset_top   = -300
	_panel.offset_bottom=  300
	var sbox = StyleBoxFlat.new()
	sbox.bg_color = Color(0.02, 0.04, 0.07, 0.97)
	sbox.border_color = Color(0.67, 0.53, 0.32)
	sbox.set_border_width_all(2)
	sbox.corner_radius_top_left = 8
	sbox.corner_radius_top_right = 8
	sbox.corner_radius_bottom_left = 8
	sbox.corner_radius_bottom_right = 8
	sbox.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", sbox)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	_panel.add_child(vbox)

	_round_lbl = _lbl(vbox, "ESQUINA", 30, Color("edc27e"))
	_injury_lbl = _lbl(vbox, "", 13, Color("e07070"))
	var sep = HSeparator.new(); vbox.add_child(sep)
	_stats_lbl = _lbl(vbox, "", 13, Color("a8b6c6"))
	var sep2 = HSeparator.new(); vbox.add_child(sep2)
	_lbl(vbox, "TRATAMIENTO (elige uno):", 14, Color("b5c4d0"))

	for t in TREATMENTS:
		var btn = Button.new()
		btn.text = "%s  %s" % [t["icon"], t["label"]]
		btn.custom_minimum_size = Vector2(0, 42)
		btn.pressed.connect(_on_treatment.bind(t["id"]))
		vbox.add_child(btn)
		_buttons.append(btn)

	var sep3 = HSeparator.new(); vbox.add_child(sep3)
	_tip_lbl = _lbl(vbox, "", 14, Color("f5d49d"))
	_time_lbl = _lbl(vbox, "", 20, Color.WHITE)

func _lbl(parent: Node, text: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func show_corner(round_num: int) -> void:
	_chosen = false
	_round_lbl.text = "⚪ FIN DEL ROUND %d — ESQUINA" % round_num
	for btn in _buttons: btn.disabled = false

	# Lesiones
	if injury_p:
		var labels = injury_p.injury_labels()
		if labels.is_empty():
			_injury_lbl.text = "Sin lesiones significativas"
		else:
			_injury_lbl.text = " | ".join(labels.map(func(a): return "%s: %s" % [a[0], a[1]]))

	# Estadísticas
	if momentum:
		var sp = momentum.stats_player
		var se = momentum.stats_enemy
		var pp = "%.0f%%" % (momentum.precision(true) * 100)
		var ep = "%.0f%%" % (momentum.precision(false) * 100)
		_stats_lbl.text = \
			"ALONSO         VEGA\n" + \
			"%3d  Lanzados   %3d\n" % [sp["thrown"], se["thrown"]] + \
			"%3d  Conectados %3d\n" % [sp["connected"], se["connected"]] + \
			"%3s  Precisión  %3s\n" % [pp, ep] + \
			"%3d  Cabeza     %3d\n" % [sp["head"], se["head"]] + \
			"%3d  Cuerpo     %3d\n" % [sp["body"], se["body"]] + \
			"%3d  Counters   %3d"   % [sp["counters"], se["counters"]]

	_tip_lbl.text = _generate_tip()
	visible = true

func hide_corner() -> void:
	visible = false

func _on_treatment(id: String) -> void:
	if _chosen or not injury_p: return
	_chosen = true
	var result = injury_p.corner_treat(id)
	if fight and fight.player:
		fight.player.stamina = minf(100.0, fight.player.stamina + result["stamina_bonus"])
		fight.player.health  = minf(100.0, fight.player.health  + result["health_bonus"])
	_tip_lbl.text = "✅ " + result["msg"]
	for btn in _buttons: btn.disabled = true

func _generate_tip() -> String:
	if not fight or not fight.player: return ""
	var tips = [
		"💡 Prueba jab + paso atrás para crear distancia.",
		"💡 Sus hooks llegan tarde. Slip izquierda y contra con cross.",
		"💡 Está entrando después de tu jab. Jab + paso atrás + uppercut.",
		"💡 Usa body shots para bajarle las manos.",
		"💡 Al clinch, empuja y resetea la distancia.",
		"💡 Cuando retroceda, sigue con jab + cross + hook."
	]
	if momentum:
		if momentum.momentum < -0.3:
			return "⚠ Está dominando. Juega más defensivo y busca counters."
		if momentum.momentum > 0.3:
			return "💪 Llevas ventaja. Mantén la presión con combinaciones."
	return tips[randi() % tips.size()]

func _process(delta: float) -> void:
	if not visible or not fight: return
	var remaining = fight.phase_time if fight.phase == fight.Phase.REST else 0.0
	_time_lbl.text = "Próximo round en: %d s" % int(ceil(remaining))
