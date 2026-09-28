extends Node3D

@export var player: Node3D
@export var enemy: Node3D
@export var min_zoom: float = 2.5
@export var max_zoom: float = 6.0
@export var height_offset: float = 0.8
@export var smooth_speed: float = 5.0
@export var side_offset: float = 1.0

@onready var cam = $Camera3D

func _process(delta: float) -> void:
	if not player or not enemy: return
	
	# Calculate midpoint
	var midpoint = (player.global_position + enemy.global_position) / 2.0
	midpoint.y += height_offset
	
	# Add a slight angle/offset so it's not perfectly straight
	var dir = (enemy.global_position - player.global_position).normalized()
	var right = Vector3(-dir.z, 0, dir.x)
	midpoint += right * side_offset
	
	var dist = player.global_position.distance_to(enemy.global_position)
	# Zoom closer when they are fighting, wider when separated
	var target_z = clamp(dist * 1.5, min_zoom, max_zoom)
	
	# Smoothly move rig to midpoint
	global_position = global_position.lerp(midpoint, smooth_speed * delta)
	
	# Look slightly down at the fighters
	var target_look = midpoint
	target_look.y -= 0.3
	var current_look = global_transform.basis * Vector3.FORWARD
	var desired_transform = global_transform.looking_at(target_look, Vector3.UP)
	global_transform.basis = global_transform.basis.slerp(desired_transform.basis, smooth_speed * delta)
	
	# Smoothly zoom camera
	cam.position.z = lerpf(cam.position.z, target_z, smooth_speed * delta)
