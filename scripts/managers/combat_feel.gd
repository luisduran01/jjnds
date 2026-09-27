extends Node

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var original_cam_transform: Transform3D
var active_camera: Camera3D

func _process(delta: float) -> void:
	if shake_duration > 0 and active_camera:
		shake_duration -= delta
		var offset = Vector3(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity),
			0
		)
		active_camera.h_offset = offset.x
		active_camera.v_offset = offset.y
		
		if shake_duration <= 0:
			active_camera.h_offset = 0
			active_camera.v_offset = 0
			active_camera = null

func hitstop(duration: float = 0.05) -> void:
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration * 0.1).timeout
	Engine.time_scale = 1.0

func camera_shake(intensity: float = 0.2, duration: float = 0.2) -> void:
	active_camera = get_viewport().get_camera_3d()
	if active_camera:
		shake_intensity = intensity
		shake_duration = duration

func spawn_sweat(pos: Vector3) -> void:
	# Creamos un sistema de partículas simple por código
	var particles = CPUParticles3D.new()
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(particles)
		particles.global_position = pos
		particles.emitting = true
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.lifetime = 0.5
		particles.direction = Vector3(0, 1, 0)
		particles.spread = 45.0
		particles.initial_velocity_min = 2.0
		particles.initial_velocity_max = 4.0
		particles.scale_amount_min = 0.02
		particles.scale_amount_max = 0.05
		
		# Material para que parezca sudor (blanco/transparente)
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.9, 1.0, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		particles.material_override = mat
		
		var mesh = SphereMesh.new()
		particles.mesh = mesh
		
		await get_tree().create_timer(1.0).timeout
		if is_instance_valid(particles):
			particles.queue_free()
