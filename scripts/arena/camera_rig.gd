extends Node3D

@export var player: Node3D
@export var enemy: Node3D
@export var min_zoom: float = 4.0
@export var max_zoom: float = 8.0
@export var height_offset: float = 1.3
@export var smooth_speed: float = 4.5

@onready var cam = $Camera3D

func _process(delta: float) -> void:
	if not player or not enemy: return
	
	var midpoint = (player.global_position + enemy.global_position) / 2.0
	midpoint.y += height_offset
	
	var dist = player.global_position.distance_to(enemy.global_position)
	var target_z = clamp(dist * 1.2, min_zoom, max_zoom)
	
	# Smoothly move rig to midpoint
	global_position = global_position.lerp(midpoint, smooth_speed * delta)
	
	# Smoothly zoom camera
	cam.position.z = lerpf(cam.position.z, target_z, smooth_speed * delta)
