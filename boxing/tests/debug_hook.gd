extends SceneTree

const Fighter = preload("res://boxing/characters/fighter.gd")
const Punches = preload("res://boxing/combat/punches.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	load("res://boxing/managers/input_setup.gd").install()
	var floor_body=StaticBody3D.new()
	var floor_shape=CollisionShape3D.new()
	var floor_box=BoxShape3D.new()
	floor_box.size=Vector3(15,.2,15)
	floor_shape.shape=floor_box
	floor_shape.position.y=-.1
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var a = Fighter.new()
	var b = Fighter.new()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.fighting = true
	b.fighting = true
	for i in 8: await physics_frame
	for punch in Punches.DATA:
		var d := Punches.get_punch(punch)
		a.position=Vector3(0,0,0)
		b.position=Vector3(0,0,.65)
		a.rotation.y=0
		b.rotation.y=PI
		a.stamina=100
		b.health=100
		b.knockdown_meter=0
		b.head_damage=0
		b.stun=0
		a.set_state(a.State.IDLE)
		b.set_state(b.State.IDLE)
		for i in 5: await physics_frame
		a.attack(punch)
		var best_h := 9.0
		var best_b := 9.0
		var best_t := 0.0
		for i in 65:
			await physics_frame
			var hand: int = int(d["hand"])
			var fist: Vector3 = a.fists[hand].global_position
			var dh: float = fist.distance_to(b.hurts[0].global_position)-(0.13+0.19)
			var db: float = fist.distance_to(b.hurts[1].global_position)-(0.13+0.245)
			if a.state == a.State.ATTACKING and a.attack_time >= Punches.live_window(punch).x and a.attack_time <= Punches.live_window(punch).y:
				if dh < best_h: best_h = dh
				if db < best_b: best_b = db
				best_t = a.attack_time
			if b.health < 100: break
		print("%-14s health=%.1f  closest head gap=%.3f body gap=%.3f at t=%.3f  bstate=%s bshin=%.0f"
			% [punch, b.health, best_h, best_b, best_t, b.State.keys()[b.state], rad_to_deg(b.skeleton.get_bone_pose_rotation(b.skeleton.find_bone("Chest")).get_euler().x)])
	quit(0)
