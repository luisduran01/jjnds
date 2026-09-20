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
