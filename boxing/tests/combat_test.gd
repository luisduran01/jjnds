extends SceneTree
var failures=0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool,message: String) -> void:
	if not value:
		failures+=1
		push_error("TEST FAILED: "+message)

func run() -> void:
	load("res://boxing/managers/input_setup.gd").install()
	if not ResourceLoader.exists("res://boxing/characters/fighter.gd"):
		push_error("TEST FAILED: fighter with physical hit detection is missing")
		quit(1)
		return
	var script = load("res://boxing/characters/fighter.gd")
	var floor_body=StaticBody3D.new()
	var floor_shape=CollisionShape3D.new()
	var floor_box=BoxShape3D.new()
	floor_box.size=Vector3(15,.2,15)
	floor_shape.shape=floor_box
	floor_shape.position.y=-.1
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var a = script.new()
	var b = script.new()
	root.add_child(a)
	root.add_child(b)
	check(a.skeleton!=null and b.skeleton!=null,"both rigs must be imported")
	a.opponent = b
	b.opponent = a
	a.position = Vector3(0,0,0)
	b.position = Vector3(0,0,4)
	a.fighting = true
	b.fighting = true
	b.is_player = true
	await physics_frame
	a.stamina = 0
	check(not a.attack("cross"),"exhausted boxer cannot punch")
	a.stamina = 100
	check(a.attack("jab"),"fresh boxer can jab")
	for i in 45: await physics_frame
	check(is_equal_approx(b.health,100.0),"out of reach punches cause no damage")
	var first = b.receive_hit(a,"jab","head",1.0,1.0,42)
	var hp = b.health
	var second = b.receive_hit(a,"jab","head",1.0,1.0,42)
	check(first and not second and is_equal_approx(hp,b.health),"one impact per attack")
	a.position=Vector3(0,0,0)
	b.position=Vector3(0,0,.75)
	for i in 45: await physics_frame
	a.stamina=100
	var before=b.health
	a.attack("jab")
	for i in 40:
		await physics_frame
	check(b.health<before,"animated physical jab should connect at fighting range")
	for punch in load("res://boxing/combat/punches.gd").DATA:
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
		for i in 65: await physics_frame
		check(b.health<100,"physical contact: "+punch)
	# High block reduces head damage but cannot cover the body.
	b.health=100
	b.guard=100
	b.stun=0
	b.knockdown_meter=0
	b.set_state(b.State.BLOCKING)
	b.defense="block_high"
	b.receive_hit(a,"jab","head",1,1,101)
	var blocked_damage=100-b.health
	b.health=100
	b.receive_hit(a,"jab","body",1,1,102)
	check(100-b.health>blocked_damage*2,"high guard does not protect body")
	a.set_state(a.State.IDLE)
	a.stamina=100
	a.attack("jab")
	a.receive_hit(b,"cross","head",1,1,900)
	check(a.current_punch=="","interrupted punch must not remain active for AI")
	a.queue_free()
	b.queue_free()
	await process_frame
	await test_flow()
	print("COMBAT + FLOW TEST FAILURES: ",failures)
	quit(1 if failures>0 else 0)

func test_flow() -> void:
	var scene=load("res://boxing/main.tscn").instantiate()
	root.add_child(scene)
	var fight=scene.fight
	scene.brain.set_physics_process(false)
	fight.set_process(false)
	fight.begin()
	check(fight.phase==fight.Phase.ROUND_START,"start enters intro")
	fight._process(3)
	check(fight.phase==fight.Phase.FIGHTING,"intro starts fighting")
	fight.player.round_quality=20
	fight.remaining=.01
	fight._process(.02)
	check(fight.phase==fight.Phase.ROUND_END,"timer ends round")
	check(fight.total_player==10 and fight.total_enemy==9,"round scored 10-9")
	fight._process(3)
	check(fight.phase==fight.Phase.REST,"rest follows round")
	fight._process(20)
	check(fight.round_number==2,"next round increments")
	fight._process(3)
	var victim=fight.enemy
	victim.knockdowns=1
	victim.round_knockdowns=1
	victim.set_state(victim.State.KNOCKDOWN)
	fight.on_knockdown(victim)
	var time=fight.remaining
	fight._process(1)
	check(fight.remaining==time and not fight.player.fighting,"count pauses combat clock")
	fight.count=4
	fight.rise_progress=8
	fight.phase_time=0
	fight._process(.1)
	check(victim.state==victim.State.GET_UP,"healthy AI rises after count five")
	# Animation completes before the referee's longer verification delay.
	victim.set_state(victim.State.IDLE)
	fight._process(2)
	check(fight.phase==fight.Phase.FIGHTING,"combat resumes after get-up animation completes")
	fight.change(fight.Phase.FIGHTING)
	victim.round_knockdowns=3
	victim.set_state(victim.State.KNOCKDOWN)
	fight.on_knockdown(victim)
	check(fight.phase==fight.Phase.FIGHT_END and "TKO" in fight.result,"three down rule ends fight")
	fight.change(fight.Phase.FIGHTING)
	fight.three_knockdown_rule=false
	victim.health=0
	victim.set_state(victim.State.KNOCKDOWN)
	fight.on_knockdown(victim)
	check(fight.phase==fight.Phase.KNOCKDOWN,"three-down rule can be disabled")
	fight.count=9
	fight.phase_time=0
	fight._process(.1)
	check(fight.phase==fight.Phase.FIGHT_END and "KO" in fight.result,"count ten awards KO")
	fight.change(fight.Phase.FIGHTING)
	fight.down_fighter=null
	fight.round_number=3
	fight.player.round_quality=40
	fight.enemy.round_quality=0
	fight.remaining=.01
	fight._process(.1)
	fight._process(3)
	check(fight.phase==fight.Phase.FIGHT_END and "DECISIÓN" in fight.result,"final round ends in decision")
	var f=fight.enemy
	f.fighting=true
	f.set_state(f.State.DODGING,.5,"duck")
	fight.player.current_punch="jab"
	fight.player.position=f.position+Vector3(.5,0,0)
	for i in 20:
		scene.brain.observed_attack=""
		scene.brain.decide()
	check(f.state==f.State.DODGING,"AI cannot cancel dodge into block")
	scene.queue_free()
	await process_frame
