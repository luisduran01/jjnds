extends SceneTree

# Geometry check for the punch poses: walks every punch clip, follows the fist
# through its live window and reports where it actually arrives, so the range
# bands in punches.gd stay honest with the animation.

const Animations = preload("res://boxing/characters/animation_factory.gd")
const Punches = preload("res://boxing/combat/punches.gd")

const FIST_RADIUS := 0.13
const HEAD_RADIUS := 0.19
const BODY_RADIUS := 0.245
const HEAD_HEIGHT := 1.77
const BODY_HEIGHT := 1.30

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func hurtbox(zone: String, distance: float) -> Vector3:
	return Vector3(0.0, HEAD_HEIGHT if zone == "head" else BODY_HEIGHT, distance)

func run() -> void:
	print("PUNCH GEOMETRY (fist reach in model space, opponent on +Z)")
	for clip in Punches.DATA.keys():
		var d := Punches.get_punch(clip)
		var dur: float = float(d["duration"])
		var hand: int = int(d["hand"])
		var window := Punches.live_window(clip)
		var drive: float = float(d["drive"])
		var max_z := -9.0
		var contact_head := 0.0
		var contact_body := 0.0
		var reach_z := 0.0
		for k in 121:
			var t := float(k) / 120.0
			var pose := Animations.pose_for(clip, t)
			var fists: Array = pose["_fist"]
			var fist: Vector3 = fists[hand]
			var push := 0.0
			var live_end: float = window.y / dur
			var u: float = t
			if u < live_end:
				push = clampf(t / maxf(live_end, 0.01), 0.0, 1.0)
			else:
				push = maxf(0.0, 1.0 - (u - live_end) / 0.35)
			var world := fist + Vector3(0.0, 0.0, drive * push)
			max_z = maxf(max_z, world.z)
			var live: bool = t * dur >= window.x and t * dur <= window.y
			if not live:
				continue
			for step in 19:
				var distance := 0.46 + float(step) * 0.05
				var head_gap: float = world.distance_to(hurtbox("head", distance)) - (FIST_RADIUS + HEAD_RADIUS)
				var body_gap: float = world.distance_to(hurtbox("body", distance)) - (FIST_RADIUS + BODY_RADIUS)
				if head_gap <= 0.0: contact_head = maxf(contact_head, distance)
				if body_gap <= 0.0: contact_body = maxf(contact_body, distance)
		reach_z = max_z
		# Test expectation: at 0.65 every punch must connect during its window.
		if contact_head < 0.65 and contact_body < 0.65:
			failures += 1
			print("  FAIL %s never reaches a hurtbox at 0.65" % clip)
		print("%-14s hand=%d live=%.2f-%.2f maxFistZ=%.2f contact: head<=%.2f body<=%.2f declared reach=%.2f"
			% [clip, hand, window.x, window.y, reach_z, contact_head, contact_body, float(d["reach"])])
	print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
