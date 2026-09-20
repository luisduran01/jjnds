extends Node

func hitstop(duration: float = 0.05) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration * 0.05).timeout
	Engine.time_scale = 1.0

func camera_shake(intensity: float = 0.2, duration: float = 0.2) -> void:
	# Placeholder for camera shake logic
	pass
