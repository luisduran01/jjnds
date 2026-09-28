extends SceneTree

const FighterScript = preload("res://boxing/characters/fighter.gd")
const ACTIONS := ["cross", "right_hook", "right_uppercut", "body_jab", "body_cross"]

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
	for action in ACTIONS:
		var attacker := FighterScript.new()
		var defender := FighterScript.new()
		root.add_child(attacker)
		root.add_child(defender)
		attacker.global_position=Vector3.ZERO
		defender.global_position=Vector3(0,0,.65)
		attacker.opponent=defender
		defender.opponent=attacker
		attacker.fighting=true
		defender.fighting=true
		await physics_frame
		attacker.attack(action)
		var target := defender.hurts[1 if action.begins_with("body") else 0].global_position
		var closest := [999.0,999.0]
		for frame in 48:
			await physics_frame
			for hand in 2:
				closest[hand]=minf(closest[hand],attacker.fist_points[hand].global_position.distance_to(target))
		print(action," left=",snapped(closest[0],.01)," right=",snapped(closest[1],.01))
		attacker.queue_free()
		defender.queue_free()
		await process_frame
	floor.queue_free()
	quit()
