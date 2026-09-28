extends SceneTree

# Reach / reaction / zone / lower-body regression.
#
# Guards the things that were actually broken or unverified:
#  1. the rig's arm geometry has ONE source of truth and stays in human proportion
#  2. every punch family reaches a different, mechanically coherent distance
#  3. procedural reactions survive the AnimationTree, per punch family
#  4. a punch resolves to the hurtbox it is aimed at, never to the wrong zone
#  5. the procedural lower body never sinks a foot, drifts the pelvis or stacks

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	load("res://boxing/managers/input_setup.gd").install()
	var ReachProfile = load("res://boxing/characters/reach_profile.gd")
	var Punches = load("res://boxing/combat/punches.gd")
	test_geometry(ReachProfile)
	await test_fight(ReachProfile, Punches)
	print("REACH + REACTION TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)

func test_geometry(ReachProfile) -> void:
	var base = {"upper": 0.25, "lower": 0.23, "total": 0.48, "stature": 1.82, "shoulder_x": 0.21}
	var resolved = ReachProfile.resolve(base, 1.0, 1.0)
	check(resolved.bone_scale <= ReachProfile.MAX_BONE_SCALE + 0.0001, "arm lengthening stays inside the natural ceiling")
	check(resolved.bone_scale >= ReachProfile.MIN_LENGTHEN - 0.0001, "arm lengthening never shrinks the limb below safe")
	check(resolved.lengthen <= ReachProfile.MAX_LENGTHEN + 0.0001, "rig naturalisation is capped, no rubber arms")
	check(resolved.total > resolved.base_total, "short-armed rig is brought toward human proportion")
	# The whole point of the cap: the arm must stay short of full anatomical reach,
	# with the remaining range paid for by mechanics.
	check(resolved.total < resolved.anatomical, "bone length alone never reaches anatomical span (mechanics must pay the rest)")
	check(absf(resolved.upper + resolved.lower - resolved.total) < 0.0001, "resolved segments agree with resolved total")
	# A long-reach boxer may differ, but never past the same ceiling.
	var long_armed = ReachProfile.resolve(base, 1.18, 1.0)
	check(long_armed.bone_scale <= ReachProfile.MAX_BONE_SCALE + 0.0001, "reach stat cannot push the arm past the display ceiling")
	check(long_armed.bone_scale > resolved.bone_scale, "reach stat still differentiates boxers")
	# Per-punch budget ordering, straight > hook > uppercut.
	var straight = ReachProfile.extension_for(resolved, "cross")
	var hook = ReachProfile.extension_for(resolved, "left_hook")
	var upper = ReachProfile.extension_for(resolved, "left_uppercut")
	check(straight > hook and hook > upper, "arm budget ordered straight > hook > uppercut")
	check(ReachProfile.extension_for(resolved, "jab") < straight, "cross spends more arm than jab")
	check(ReachProfile.extension_for(resolved, "body_jab") < ReachProfile.extension_for(resolved, "jab"), "body jab is shorter than a head jab")
	# Reactions: a jab must never sting like a cross.
	var jab = ReachProfile.reaction_angle("jab", 4.5, 80.0, 0.0, 1.0)
	var cross = ReachProfile.reaction_angle("cross", 4.5, 80.0, 0.0, 1.0)
	var uppercut = ReachProfile.reaction_angle("left_uppercut", 4.5, 80.0, 0.0, 1.0)
	check(jab < cross * 0.6, "jab reaction is clearly smaller than a cross")
	check(cross > 0.3, "a clean cross rings the bell (>=17 deg)")
	check(uppercut > 0.15, "an uppercut produces a real reaction")
	check(ReachProfile.reaction_angle("cross", 4.5, 80.0, 0.70, 1.0) < cross * 0.45, "a block absorbs most of the reaction")
	check(ReachProfile.reaction_angle("cross", 9.9, 80.0, 0.0, 1.0) <= ReachProfile.MAX_REACTION_RAD + 0.0001, "reaction is clamped so the neck cannot fold")
	for punch in PunchesNames:
		check(ReachProfile.CHAIN.has(punch), "every punch has a kinetic chain: " + punch)

func test_fight(ReachProfile, Punches) -> void:
	var floor_body = StaticBody3D.new()
	var floor_shape = CollisionShape3D.new()
	var floor_box = BoxShape3D.new()
	floor_box.size = Vector3(15, .2, 15)
	floor_shape.shape = floor_box
	floor_shape.position.y = -.1
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var F = load("res://boxing/characters/fighter.gd")
	var a = F.new()
	var b = F.new()
	root.add_child(a)
	root.add_child(b)
	a.opponent = b
	b.opponent = a
	a.position = Vector3(0, 0, 0)
	b.position = Vector3(0, 0, 3)
	a.fighting = true
	b.fighting = true
	await physics_frame
	await physics_frame

	# --- arm geometry is wired, not merely computed ---
	var arm_bone: int = a.skeleton.find_bone("LeftUpperArm")
	var pose_scale: Vector3 = a.skeleton.get_bone_pose_scale(arm_bone)
	check(absf(pose_scale.x - a.reach.bone_scale) < 0.001, "the skinned arm actually carries the resolved scale")
	check(pose_scale.y == 1.0 and pose_scale.z == 1.0, "arm scale lengthens only, never fattens")
	var forearm: Vector3 = a.skeleton.get_bone_pose_scale(a.skeleton.find_bone("LeftForeArm"))
	check(absf(forearm.x - a.reach.bone_scale) < 0.001, "forearm carries the same resolved scale")
	# --- no visual deformation: lengthened, never rubberised ---
	# The rig's own stature drives the anthropometric band, so this cannot drift.
	var arm_ratio: float = a.reach.total / 1.82
	check(arm_ratio > 0.28 and arm_ratio < 0.36, "arm/stature ratio stays inside the human band (%.3f)" % arm_ratio)
	check(a.reach.total < a.reach.anatomical, "the model is still shorter-armed than anatomy, so it cannot read as stretched")
	check(absf(pose_scale.y - 1.0) < 0.0001 and absf(pose_scale.z - 1.0) < 0.0001, "arm is scaled along its length only, never fattens")
	check(a.reach.upper / a.reach.lower > 0.85 and a.reach.upper / a.reach.lower < 1.25, "upper/forearm segment ratio stays plausible")
	check(absf(a.reach.shoulder_x - 0.21) < 0.02, "shoulder width is untouched by the arm naturalisation")
	# The fist the player sees must be the fist the IK solved for: no gap between
	# the intended target and the skinned hand.
	var hand_bone: int = a.skeleton.find_bone("LeftHand")
	var shoulder_bone: int = a.skeleton.find_bone("LeftUpperArm")
	var bone_span: float = (a.skeleton.get_bone_global_pose(hand_bone).origin - a.skeleton.get_bone_global_pose(shoulder_bone).origin).length() * a.body_profile.height_scale
	check(bone_span <= a.reach.total + 0.001, "the skinned arm respects the resolved segment lengths")

	# --- per-punch reach, measured from the real fist bone ---
	var measured := {}
	var heights := {}
	for punch in Punches.DATA:
		a.set_state(a.State.IDLE)
		a.stamina = 100
		a.rotation.y = 0
		a.position = Vector3(0, 0, 0)
		b.position = Vector3(0, 0, 8)
		for i in 4:
			await physics_frame
		var hand: int = Punches.DATA[punch][5]
		check(a.attack(punch), "punch starts: " + punch)
		var peak := -99.0
		var peak_height := 0.0
		for i in 70:
			await physics_frame
			# Height is sampled AT the furthest point: a peak height over the whole
			# clip would just report the guard stance and prove nothing.
			var local = a.fist_points[hand].global_position - a.global_position
			if local.z > peak:
				peak = local.z
				peak_height = local.y
		measured[punch] = peak
		heights[punch] = peak_height
		check(a.effective_reach <= a.reach.total + 0.0001, "reported reach never exceeds the bone chain: " + punch)
		check(peak > 0.25, "punch actually extends: " + punch)
	print("reach table: ", measured)
	print("height at peak reach: ", heights)
	# Head punches arrive high, body punches arrive low: the target height is part
	# of the punch, not a coat of paint on the pose.
	check(heights["jab"] > 1.55 and heights["cross"] > 1.55, "head straights arrive at head height")
	check(heights["body_jab"] < 1.50 and heights["body_cross"] < 1.50, "body straights drop to the body")
	check(heights["body_hook"] < heights["left_hook"] - 0.15, "a body hook drops well below a head hook")
	check(heights["left_uppercut"] > 1.50, "uppercuts arrive up under the chin")
	# Ordered by boxing mechanics, and genuinely distinct, not one shared range.
	check(measured["cross"] > measured["jab"], "cross out-ranges jab")
	check(measured["jab"] - measured["left_hook"] > 0.05, "a straight clearly out-ranges a hook")
	check(measured["left_hook"] - measured["left_uppercut"] > 0.03, "a hook clearly out-ranges an uppercut")
	check(measured["body_jab"] < measured["jab"] and measured["body_cross"] < measured["cross"], "body punches are shorter than their head counterparts")
	check(measured["body_hook"] < measured["left_hook"], "body hook is shorter than a head hook")
	check(measured["cross"] < 0.95, "reach stays inside a human envelope, no rubber arms")

	# --- reactions survive the AnimationTree ---
	var head: int = a.skeleton.find_bone("Head")
	var chest: int = a.skeleton.find_bone("Chest")
	var reactions := {}
	for punch in ["jab", "cross", "left_uppercut"]:
		a.active_ragdoll.reset()
		await physics_frame
		await physics_frame
		var before: Quaternion = a.skeleton.get_bone_pose_rotation(head)
		a.active_ragdoll.apply_contact("head", Vector3(0, 1.7, 0), Vector3.RIGHT * 5.0, 80.0, 0.0, 1.0, punch, 1.0)
		for i in 3:
			await physics_frame
		reactions[punch] = rad_to_deg(before.angle_to(a.skeleton.get_bone_pose_rotation(head)))
		check(reactions[punch] > 1.0, "reaction survives the AnimationTree: " + punch)
	check(reactions["cross"] > reactions["jab"] * 1.8, "cross reaction is far stronger than a jab")
	# Uppercut sends the glove upward: a degenerate torque axis must still react.
	a.active_ragdoll.reset()
	await physics_frame
	await physics_frame
	var up_before: Quaternion = a.skeleton.get_bone_pose_rotation(head)
	a.active_ragdoll.apply_contact("head", Vector3(0, 1.7, 0), Vector3.UP * 5.0, 80.0, 0.0, 1.0, "right_uppercut", 1.0)
	for i in 3:
		await physics_frame
	check(rad_to_deg(up_before.angle_to(a.skeleton.get_bone_pose_rotation(head))) > 1.0, "a vertical uppercut still snaps a reaction")
	# Body hook folds the torso, not the head.
	a.active_ragdoll.reset()
	await physics_frame
	await physics_frame
	var chest_before: Quaternion = a.skeleton.get_bone_pose_rotation(chest)
	a.active_ragdoll.apply_contact("body", Vector3(0, 1.35, 0), Vector3.RIGHT * 5.0, 80.0, 0.0, 1.0, "body_hook", 1.0)
	for i in 3:
		await physics_frame
	check(rad_to_deg(chest_before.angle_to(a.skeleton.get_bone_pose_rotation(chest))) > 1.0, "body hook reacts in the torso")
	# Reaction decays back to the base pose on its own.
	a.active_ragdoll.reset()
	await physics_frame
	var rest_before: Quaternion = a.skeleton.get_bone_pose_rotation(head)
	for i in 150:
		await physics_frame
	check(rad_to_deg(rest_before.angle_to(a.skeleton.get_bone_pose_rotation(head))) < 0.5, "reaction recovers back to the base pose")

	# --- zone resolve: the aimed zone wins, never the engine's report order ---
	var head_y := func(): return a.hurts[0].global_position.y
	var body_y := func(): return a.hurts[1].global_position.y
	check(head_y.call() > body_y.call() + 0.2, "head hurtbox sits above the body hurtbox (not swapped)")
	check(absf(body_y.call() - (a.global_position.y + 1.30)) < 0.20, "body hurtbox sits on the chest")
	# Both hurtboxes are reachable at this range, so this is the ambiguous case
	# that used to pick whichever area the engine returned first.
	check(a.hurts[0].collision_layer == 8 and a.hurts[1].collision_layer == 8, "both hurtboxes are hittable")
	for punch in ["jab", "body_jab", "left_uppercut", "body_hook"]:
		var intended: String = "body" if punch.begins_with("body") else "head"
		b.health = 100
		b.head_damage = 0
		b.body_damage = 0
		b.knockdown_meter = 0
		b.stun = 0
		b.set_state(b.State.IDLE)
		a.set_state(a.State.IDLE)
		a.stamina = 100
		a.rotation.y = 0
		b.rotation.y = PI
		a.position = Vector3(0, 0, 0)
		b.position = Vector3(0, 0, 0.62)
		for i in 5:
			await physics_frame
		a.attack(punch)
		for i in 70:
			await physics_frame
		if intended == "body":
			check(b.body_damage > 0.0 and b.head_damage == 0.0, "%s must resolve to the body hurtbox" % punch)
		else:
			check(b.head_damage > 0.0 and b.body_damage == 0.0, "%s must resolve to the head hurtbox" % punch)

	# --- footwork: a step travels a step, then the feet plant ---
	a.set_state(a.State.IDLE)
	a.stamina = 100
	a.rotation.y = 0
	a.position = Vector3(0, 0, 0)
	b.position = Vector3(0, 0, 12)
	for i in 10:
		await physics_frame
	var prev: Vector3 = a.global_position
	var travelled := 0.0
	var peak_frame := 0.0
	var still_frames := 0
	var frames := 60
	a.move_input = Vector2(0, -1)
	for i in frames:
		await physics_frame
		var moved: float = prev.distance_to(a.global_position)
		travelled += moved
		peak_frame = maxf(peak_frame, moved)
		if moved < peak_frame * 0.10 and i > 12:
			still_frames += 1
		prev = a.global_position
	a.move_input = Vector2.ZERO
	var avg_speed: float = travelled / (float(frames) / 60.0)
	check(avg_speed > 0.7, "footwork actually closes distance (%.2f m/s)" % avg_speed)
	check(peak_frame < 0.10, "a single frame of footwork is a step, not a teleport (%.3f m)" % peak_frame)
	check(avg_speed < 2.4, "footwork is a shuffle, not a sprint (%.2f m/s)" % avg_speed)
	check(still_frames > 2, "footwork is intermittent: the feet plant between steps")

	# --- lower body integrity ---
	a.active_ragdoll.reset()
	a.position = Vector3(0, 0, 0)
	a.rotation.y = 0
	a.stamina = 100
	b.position = Vector3(0, 0, 3)
	for i in 20:
		await physics_frame
	var foot: int = a.skeleton.find_bone("RightFoot")
	var foot_base: float = (a.skeleton.global_transform * a.skeleton.get_bone_global_pose(foot).origin).y
	var lowest := foot_base
	var peak_drive := 0.0
	a.attack("cross")
	for i in 70:
		await physics_frame
		lowest = minf(lowest, (a.skeleton.global_transform * a.skeleton.get_bone_global_pose(foot).origin).y)
		peak_drive = maxf(peak_drive, a.active_ragdoll.drive_for("Hips").length())
	check(peak_drive > 0.02, "a cross actually drives the pelvis (weight transfer)")
	check(peak_drive <= a.active_ragdoll.LIMITS["Hips"] + 0.0001, "pelvis drive is bounded")
	check(lowest > foot_base - 0.02, "the procedural drive never sinks the planted foot")
	check(a.active_ragdoll.drive_for("Hips").length() < 0.0001, "pelvis drive returns to the base pose after the punch")
	check(a.model.position.y > -0.05, "model is not permanently pushed down")
	# The planted legs take the pelvis twist back out instead of sliding.
	a.set_state(a.State.IDLE)
	a.stamina = 100
	a.attack("left_hook")
	var widest := 0.0
	for i in 60:
		await physics_frame
		widest = maxf(widest, a.active_ragdoll.drive_for("LeftThigh").length())
	check(widest > 0.0, "the planted leg counter-rotates the pivot")
	check(a.active_ragdoll.drive_for("LeftThigh").length() < 0.0001, "leg counter-rotation also returns to base")

	# --- stamina routing actually reaches the model ---
	a.set_state(a.State.IDLE)
	a.stamina = 100.0
	var before_energy: float = a.stamina
	a.dodge("dodge_left")
	await physics_frame
	check(a.stamina < before_energy, "dodge drains stamina and the drain survives the next frame")
	a.set_state(a.State.IDLE)
	a.stamina = 100.0
	await physics_frame
	var guarding_from: float = a.stamina
	a.set_state(a.State.BLOCKING, 0, "block_high")
	a.defense = "block_high"
	for i in 30:
		await physics_frame
	check(a.stamina < guarding_from, "holding a guard costs stamina")
	a.set_state(a.State.IDLE)
	a.stamina = 100.0
	for i in 3:
		await physics_frame
	# A missed punch must cost more than the same punch landing, measured over the
	# same attack window so recovery time cannot mask the penalty.
	a.rotation.y = 0
	b.rotation.y = PI
	a.position = Vector3(0, 0, 0)
	b.position = Vector3(0, 0, 8)
	a.combo_count = 0
	a.combo_window = 0.0
	a.recovery = 0.0
	a.fatigue.configure(100.0, 60.0)
	a.stamina = 100.0
	for i in 3:
		await physics_frame
	var miss_from: float = a.stamina
	a.attack("jab")
	var elapsed := 0
	while a.state == a.State.ATTACKING and elapsed < 200:
		await physics_frame
		elapsed += 1
	var miss_drop: float = miss_from - a.stamina
	var miss_frames := elapsed
	a.set_state(a.State.IDLE)
	b.position = Vector3(0, 0, 0.62)
	a.combo_count = 0
	a.combo_window = 0.0
	a.recovery = 0.0
	a.fatigue.configure(100.0, 60.0)
	a.stamina = 100.0
	for i in 3:
		await physics_frame
	var land_from: float = a.stamina
	b.health = 100
	a.attack("jab")
	elapsed = 0
	while a.state == a.State.ATTACKING and elapsed < 200:
		await physics_frame
		elapsed += 1
	var land_drop: float = land_from - a.stamina
	print("stamina drop -> miss=%.2f (%d frames)  landed=%.2f (%d frames)  connected=%s  victim_health=%.1f" % [miss_drop, miss_frames, land_drop, elapsed, a.attack_connected, b.health])
	check(a.attack_connected or b.health < 100.0, "reach test setup actually lands the punch")
	check(absf(elapsed - miss_frames) <= 2, "both swings measured over the same attack window")
	check(miss_drop > land_drop + 0.5, "a missed punch costs more stamina than a landed one")
	# Body damage feeds back into stamina.
	a.stamina = 100.0
	b.stamina = 100.0
	var body_before: float = b.stamina
	b.fighting = true
	b.receive_hit(a, "body_cross", "body", 1.0, 1.0, 777)
	check(b.body_damage > 0.0 and b.stamina < body_before, "body damage drains the victim's stamina")
	check(b.stamina <= b.fatigue.energy + 0.0001, "stamina stays a mirror of the fatigue model")

	a.queue_free()
	b.queue_free()
	await process_frame

const PunchesNames := ["jab", "cross", "left_hook", "right_hook", "body_jab", "body_cross", "body_hook", "left_uppercut", "right_uppercut"]
