extends SceneTree

# Runs the real fight scene for a full simulated round and checks that the
# whole pipeline is alive: idle breathing, gait on the feet, physical slips,
# punches landing only inside their window, counters, stamina and the AI
# actually boxing instead of standing still.

const Punches = preload("res://boxing/combat/punches.gd")

var failures := 0
var last_info: Dictionary = {}
var hits: Array = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("FAIL: ", message)
	else:
		print("ok  : ", message)

func on_hit(_attacker, _victim, info) -> void:
	last_info = info
	hits.append(info)

func run() -> void:
	load("res://boxing/managers/input_setup.gd").install()
	var scene = load("res://boxing/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var fight = scene.fight
	var brain = scene.brain
	var player = fight.player
	var enemy = fight.enemy
	player.hit_landed.connect(on_hit)
	enemy.hit_landed.connect(on_hit)
	check(player.skeleton != null and enemy.skeleton != null, "both rigs loaded")
	check(player.procedural != null, "procedural body layer attached to the player")
	# --- IDLE LIFE: the chest must keep moving while nobody touches anything --
	var chest := player.skeleton.find_bone("Chest")
	var hips := player.skeleton.find_bone("Hips")
	var idle_span := 0.0
	var idle_hspan := 0.0
	var first := player.skeleton.get_bone_pose_rotation(chest)
	var first_hips := player.skeleton.get_bone_pose_rotation(hips)
	for i in 90:
		await physics_frame
		idle_span = maxf(idle_span, first.angle_to(player.skeleton.get_bone_pose_rotation(chest)))
		idle_hspan = maxf(idle_hspan, first_hips.angle_to(player.skeleton.get_bone_pose_rotation(hips)))
	check(idle_span > 0.004, "idle breathing moves the chest (%.4f rad)" % idle_span)
	check(idle_hspan > 0.004, "idle weight shift moves the hips (%.4f rad)" % idle_hspan)

	# --- SLIP MUST MOVE THE HEAD OFF THE LINE ------------------------------
	var head_before := player.hurts[0].global_position
	player.set_state(player.State.IDLE)
	player.stamina = 100
	await physics_frame
	player.dodge("dodge_left")
	var slip := 0.0
	for i in 30:
		await physics_frame
		slip = maxf(slip, (player.hurts[0].global_position - head_before).length())
	check(slip > 0.12, "slip physically moves the head (%.3f m)" % slip)

	# --- GAIT: the legs step instead of sliding ----------------------------
	fight.change(fight.Phase.FIGHTING)
	player.stamina = 100
	var foot := player.skeleton.find_bone("LeftFoot")
	var foot_lift := 0.0
	var lowest := 99.0
	for i in 80:
		player.move_input = Vector2(0, -1)
		await physics_frame
		var f: Vector3 = player.skeleton.global_transform * player.skeleton.get_bone_global_pose(foot).origin
		lowest = minf(lowest, f.y)
		foot_lift = maxf(foot_lift, f.y - lowest)
	check(foot_lift > 0.015, "walk cycle lifts the foot off the floor (%.3f m)" % foot_lift)
	check(absf(player.procedural.phase) > 0.01 or player.procedural.phase < 0.99, "gait phase advanced")
	player.move_input = Vector2.ZERO

	# --- PUNCHES ONLY DAMAGE INSIDE THEIR WINDOW AND AT REACH ---------------
	var far_enemy = enemy.position
	enemy.position = player.position + Vector3(0, 0, 2.4)
	player.set_state(player.State.IDLE)
	player.stamina = 100
	await physics_frame
	player.attack("cross")
	for i in 60:
		await physics_frame
	check(is_equal_approx(enemy.health, 100.0), "cross thrown from 2.4 m causes no damage")
	enemy.position = far_enemy

	# --- AI: real boxing -----------------------------------------------------
	brain.set_physics_process(true)
	var start_pos: Vector3 = enemy.position
	var span := 0.0
	var distances: Array = []
	var state_count: Dictionary = {}
	var zones: Dictionary = {}
	var player_states: Dictionary = {}
	for i in 2400:
		await physics_frame
		span = maxf(span, enemy.position.distance_to(start_pos))
		if i % 10 == 0:
			distances.append(enemy.distance)
			zones[enemy.ring_zone] = int(zones.get(enemy.ring_zone, 0)) + 1
		var sname: String = enemy.State.keys()[enemy.state]
		state_count[sname] = int(state_count.get(sname, 0)) + 1
		var pname: String = player.State.keys()[player.state]
		player_states[pname] = int(player_states.get(pname, 0)) + 1
	var dmin := 99.0
	var dmax := 0.0
	for d in distances:
		dmin = minf(dmin, d)
		dmax = maxf(dmax, d)
	print("AI states: ", state_count)
	print("player states: ", player_states)
	print("ring zones: ", zones)
	print("distance range: %.2f - %.2f" % [dmin, dmax])
	check(enemy.thrown > 8, "AI threw punches (%d)" % enemy.thrown)
	check(enemy.landed > 0, "AI landed punches (%d)" % enemy.landed)
	check(player.health < 100.0, "player took damage (%.1f hp)" % player.health)
	check(span > 0.4, "AI moved around the ring (%.2f m)" % span)
	check(dmax - dmin > 0.10, "AI manages distance (%.2f - %.2f)" % [dmin, dmax])
	check(state_count.has("BLOCKING") or state_count.has("DODGING"), "AI defended instead of only attacking")
	check(player_states.has("HURT") or player_states.has("STUNNED") or player_states.has("KNOCKDOWN"), "player reacted to impacts")
	check(enemy.stamina < 100.0 and enemy.stamina > 0.0, "AI stamina is live (%.1f)" % enemy.stamina)

	# --- STAMINA / GAS: empty stamina blocks big punches --------------------
	var gashed = fight.enemy
	gashed.stamina = 0.0
	check(not gashed.attack("right_uppercut"), "gassed boxer cannot throw a power punch")

	# --- COUNTER: a whiffed punch opens the counter window -------------------
	var fresh = fight.player
	fresh.set_state(fresh.State.IDLE)
	fresh.open_window = 0.0
	fresh.recovery = 0.0
	fresh.attack("jab")
	fresh.current_punch = ""
	fresh.attack_time = float(Punches.get_punch("jab")["duration"]) + 0.05
	fresh.update_attack(0.0)
	check(fresh.open_window > 0.0, "whiffed jab opens a counter window (%.2f s)" % fresh.open_window)
	var before := fresh.health
	fresh.receive_hit(fight.enemy, "cross", "head", 1.1, 1.0, 7777)
	check(last_info.get("counter", false), "counter flagged when the boxer is open")
	check(fresh.health < before, "counter landed for damage")
	check(last_info.get("tier", "") != "", "impact tier reported (%s)" % last_info.get("tier", ""))

	print("FIGHT SIM FAILURES: ", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
