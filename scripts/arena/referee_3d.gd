extends Node3D

@export var boxer_scene: PackedScene = preload("res://scenes/boxer_3d.tscn")

func _ready() -> void:
	if not boxer_scene: return
	
	var referee = boxer_scene.instantiate()
	referee.name = "RefereeModel"
	# Desactivamos el script de peleador para que no se mueva con los controles
	referee.set_script(null) 
	
	add_child(referee)
	referee.position = Vector3(0, 0, 0)
	referee.scale = Vector3(0.9, 0.9, 0.9) # Ligeramente más pequeño para distinguirlo
	
	# Cambiamos su material para que parezca un árbitro (camisa blanca)
	# Asumimos que tiene mallas adentro
	for child in referee.find_children("*", "MeshInstance3D", true):
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.85, 0.9) # Camisa blanca/gris claro
		mat.roughness = 0.8
		child.material_override = mat

func _process(delta: float) -> void:
	# Hacer que mire siempre al centro de la acción
	var p1 = get_tree().get_first_node_in_group("player")
	var p2 = get_tree().get_first_node_in_group("enemy")
	
	if p1 and p2:
		var mid = (p1.global_position + p2.global_position) / 2.0
		mid.y = global_position.y
		var look_dir = mid - global_position
		if look_dir.length_squared() > 0.1:
			var target_transform = global_transform.looking_at(mid, Vector3.UP)
			global_transform = global_transform.interpolate_with(target_transform, 3.0 * delta)
