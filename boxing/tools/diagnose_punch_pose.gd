extends SceneTree

const FighterScript = preload("res://boxing/characters/fighter.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(12,.2,12)
	collision.shape=shape
	collision.position.y=-.1
	floor.add_child(collision)
	root.add_child(floor)
	var attacker := FighterScript.new()
	var defender := FighterScript.new()
	root.add_child(attacker)
	root.add_child(defender)
	attacker.global_position=Vector3.ZERO
	defender.global_position=Vector3(0,0,.75)
	attacker.opponent=defender
	defender.opponent=attacker
	attacker.fighting=true
	defender.fighting=true
	await physics_frame
	attacker.attack("jab")
	for frame in 32:
		await physics_frame
		if frame % 3 == 0:
			print("t=",snapped(attacker.attack_time,.01)," left=",attacker.fist_points[0].global_position," head=",defender.hurts[0].global_position," dist=",snapped(attacker.fist_points[0].global_position.distance_to(defender.hurts[0].global_position),.01))
	attacker.queue_free()
	defender.queue_free()
	floor.queue_free()
	quit()
