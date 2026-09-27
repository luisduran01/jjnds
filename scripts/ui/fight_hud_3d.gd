extends CanvasLayer

@onready var p_hp = $PlayerSide/HealthBar
@onready var p_st = $PlayerSide/StaminaBar
@onready var e_hp = $EnemySide/HealthBar
@onready var e_st = $EnemySide/StaminaBar

func _ready() -> void:
	# Give the tree a frame to setup groups
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(func(v): p_hp.value = v)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(func(v): p_st.value = v)
			
	var enemy = get_tree().get_first_node_in_group("enemy")
	if enemy:
		if enemy.has_signal("health_changed"):
			enemy.health_changed.connect(func(v): e_hp.value = v)
		if enemy.has_signal("stamina_changed"):
			enemy.stamina_changed.connect(func(v): e_st.value = v)
			
	_setup_mobile_controls()

func _setup_mobile_controls() -> void:
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		# Solo mostramos en móviles o si queremos forzarlo para debug podemos quitar este if
		pass
	
	var tex = load("res://icon.svg")
	if not tex: return
	
	# Controles de Movimiento (D-Pad simple)
	var pad_node = Control.new()
	pad_node.position = Vector2(120, get_viewport().get_visible_rect().size.y - 150)
	add_child(pad_node)
	
	var dirs = [
		{"name": "ui_up", "pos": Vector2(0, -60)},
		{"name": "ui_down", "pos": Vector2(0, 60)},
		{"name": "ui_left", "pos": Vector2(-60, 0)},
		{"name": "ui_right", "pos": Vector2(60, 0)}
	]
	
	for d in dirs:
		var btn = TouchScreenButton.new()
		btn.texture_normal = tex
		btn.action = d.name
		btn.position = d.pos - Vector2(32, 32)
		btn.scale = Vector2(0.5, 0.5)
		btn.modulate = Color(1, 1, 1, 0.4)
		pad_node.add_child(btn)
		
	# Botón de Ataque
	var attack_btn = TouchScreenButton.new()
	attack_btn.texture_normal = tex
	attack_btn.action = "ui_accept"
	attack_btn.position = Vector2(get_viewport().get_visible_rect().size.x - 120, get_viewport().get_visible_rect().size.y - 120) - Vector2(32, 32)
	attack_btn.scale = Vector2(0.8, 0.8)
	attack_btn.modulate = Color(1, 0.3, 0.3, 0.6)
	add_child(attack_btn)
	
	# Botón de Bloqueo
	var block_btn = TouchScreenButton.new()
	block_btn.texture_normal = tex
	block_btn.action = "bloquear"
	block_btn.position = attack_btn.position + Vector2(-90, -40)
	block_btn.scale = Vector2(0.6, 0.6)
	block_btn.modulate = Color(0.3, 0.3, 1.0, 0.6)
	add_child(block_btn)
