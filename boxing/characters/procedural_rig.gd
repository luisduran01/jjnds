extends Node3D

# ---------------------------------------------------------------------------
# Runtime procedural layer.
#
# Runs after the AnimationTree has written the clip poses for the frame and
# composes extra body work on top of them:
#   * locomotion gait whose step phase advances with the distance the fighter
#     actually travels (plus the rotation of the facing), which is what removes
#     foot sliding;
#   * live idle: breathing, weight transfer between the legs, hip/shoulder sway,
#     small head and guard motion, so the boxer never freezes;
#   * weight transfer from movement and from the punch the controller is
#     throwing (legs -> hips -> torso), layered over the baked punch drive.
# ---------------------------------------------------------------------------

const Animations = preload("res://boxing/characters/animation_factory.gd")
const Punches = preload("res://boxing/combat/punches.gd")

const AXIS_PITCH := Vector3(1.0, 0.0, 0.0)   # lean forward / swing a limb back
const AXIS_YAW := Vector3(0.0, 1.0, 0.0)     # turn the body
const AXIS_ROLL := Vector3(0.0, 0.0, 1.0)    # tilt towards the boxer's right

const STRIDE := 1.12          # metres of travel per full gait cycle
const BREATH_PERIOD := 3.10   # seconds per breathing cycle
const HIP_HALF_WIDTH := 0.19  # metres, used to turn facing into foot travel

const HIPS := "Hips"
const SPINE := "Spine"
const CHEST := "Chest"
const NECK := "Neck"
const HEAD := "Head"
const LEGS: Array = ["LeftThigh", "LeftShin", "LeftFoot", "RightThigh", "RightShin", "RightFoot"]
const SWAY_BONES: Array = [HIPS, SPINE, CHEST, NECK, HEAD]

var fighter: CharacterBody3D
var skeleton: Skeleton3D
var bones: Dictionary = {}
var applied: Dictionary = {}
var phase := 0.0
var clock := 0.0
var speed := 0.0
var weight := 0.0
var lean := Vector2.ZERO
var last_yaw := 0.0
var armed := false

func setup(owner_fighter: CharacterBody3D, rig: Skeleton3D) -> void:
	fighter = owner_fighter
	skeleton = rig
	var names: Array = LEGS.duplicate()
	names.append_array(SWAY_BONES)
	for index_name in names:
		var index := skeleton.find_bone(str(index_name))
		if index >= 0:
			bones[str(index_name)] = index
			applied[index] = Quaternion.IDENTITY
	last_yaw = owner_fighter.rotation.y
	name = "ProceduralRig"
	armed = not bones.is_empty()
	process_priority = 10

func _physics_process(delta: float) -> void:
	if not armed or fighter == null or skeleton == null:
		return
	clock += delta
	var travel_speed := _horizontal_speed()
	speed = lerpf(speed, travel_speed, 1.0 - exp(-delta * 9.0))
	var state = fighter.state
	var down: bool = state in [fighter.State.KNOCKDOWN, fighter.State.KO, fighter.State.DEFEAT]
	var floating: bool = state in [fighter.State.KNOCKDOWN, fighter.State.KO, fighter.State.GET_UP, fighter.State.DEFEAT, fighter.State.VICTORY, fighter.State.KNOCKDOWN]
	var struck: bool = state in [fighter.State.HURT, fighter.State.STUNNED]
	var attacking: bool = state == fighter.State.ATTACKING
	var grounded: bool = not (down or floating or struck)

	# --- gait phase from real travel and real turning ---------------------
	var travel: float = travel_speed * delta
	var turned: float = absf(angle_difference(last_yaw, fighter.rotation.y))
	last_yaw = fighter.rotation.y
	var advance: float = travel + turned * HIP_HALF_WIDTH
	if not grounded:
		advance *= 0.3
	phase = fposmod(phase + advance / STRIDE, 1.0)

	var authority := 0.0
	if down or floating or struck:
		authority = 0.0
	elif attacking:
		authority = 0.30 * clampf(speed / 1.6, 0.0, 1.0)
	else:
		authority = smoothstep(0.10, 0.55, speed)

	# --- weight transfer target ------------------------------------------
	var wanted_weight: float = fighter.weight
	if attacking:
		wanted_weight = lerpf(wanted_weight, punch_weight(fighter.current_punch, fighter.attack_time), 0.85)
	weight = lerpf(weight, clampf(wanted_weight, -1.0, 1.0), 1.0 - exp(-delta * 7.0))
	lean = lean.lerp(_movement_lean(), 1.0 - exp(-delta * 6.0))

	# --- legs: replace the clip gait with a distance locked step ----------
	var gait := Animations.gait_legs(fighter.move_input, phase, clampf(speed / 1.5, 0.0, 1.0))
	for bone in LEGS:
		if not bones.has(bone):
			continue
		var base: Quaternion = _base(bones[bone])
		var target: Quaternion = base.slerp(gait.get(bone, Quaternion.IDENTITY), authority)
		_write(bones[bone], target)

	# --- torso life: breathing, sway, weight transfer, lean --------------
	var breath := sin(clock * TAU / BREATH_PERIOD)
	var sway := sin(clock * TAU / BREATH_PERIOD - 1.35)
	var idle_amount: float = (1.0 - clampf(speed / 1.2, 0.0, 1.0)) if grounded else 0.5
	var hips_delta := Quaternion.IDENTITY
	var spine_delta := Quaternion.IDENTITY
	var chest_delta := Quaternion.IDENTITY
	var neck_delta := Quaternion.IDENTITY
	var head_delta := Quaternion.IDENTITY
	# Weight transfer is always active: the legs carry the body into the punch
	# and into the direction of travel.
	hips_delta = hips_delta * Animations.q_axis(AXIS_ROLL, -weight * Animations.d(3.4))
	hips_delta = hips_delta * Animations.q_axis(AXIS_YAW, weight * Animations.d(2.2))
	chest_delta = chest_delta * Animations.q_axis(AXIS_ROLL, -weight * Animations.d(2.0))
	chest_delta = chest_delta * Animations.q_axis(AXIS_YAW, weight * Animations.d(1.4))
	# Lean into acceleration and deceleration.
	hips_delta = hips_delta * Animations.q_axis(AXIS_PITCH, lean.y * Animations.d(3.2))
	chest_delta = chest_delta * Animations.q_axis(AXIS_PITCH, lean.y * Animations.d(2.6))
	hips_delta = hips_delta * Animations.q_axis(AXIS_ROLL, -lean.x * Animations.d(3.0))
	chest_delta = chest_delta * Animations.q_axis(AXIS_ROLL, -lean.x * Animations.d(2.4))
	# Idle life: breathing lifts the chest, the weight rocks between the legs,
	# the shoulders and the head ride along with it.
	hips_delta = hips_delta * Animations.q_axis(AXIS_YAW, sway * Animations.d(2.6) * idle_amount)
	hips_delta = hips_delta * Animations.q_axis(AXIS_ROLL, sway * Animations.d(2.2) * idle_amount)
	hips_delta = hips_delta * Animations.q_axis(AXIS_PITCH, sway * Animations.d(1.2) * idle_amount)
	spine_delta = spine_delta * Animations.q_axis(AXIS_PITCH, (breath * 0.9 + sway * 1.1) * Animations.d(1.7) * idle_amount)
	spine_delta = spine_delta * Animations.q_axis(AXIS_ROLL, sway * Animations.d(1.9) * idle_amount)
	chest_delta = chest_delta * Animations.q_axis(AXIS_PITCH, breath * Animations.d(1.2) * idle_amount)
	chest_delta = chest_delta * Animations.q_axis(AXIS_ROLL, sway * Animations.d(2.3) * idle_amount)
	neck_delta = neck_delta * Animations.q_axis(AXIS_PITCH, breath * Animations.d(0.7) * idle_amount)
	head_delta = head_delta * Animations.q_axis(AXIS_YAW, -sway * Animations.d(3.2) * idle_amount)
	head_delta = head_delta * Animations.q_axis(AXIS_PITCH, sin(clock * TAU / BREATH_PERIOD * 2.0) * Animations.d(0.9) * idle_amount)
	_write_add(bones.get(HIPS, -1), hips_delta)
	_write_add(bones.get(SPINE, -1), spine_delta)
	_write_add(bones.get(CHEST, -1), chest_delta)
	_write_add(bones.get(NECK, -1), neck_delta)
	_write_add(bones.get(HEAD, -1), head_delta)

# How much weight the body is carrying, -1 (back foot) .. +1 (front foot).
func punch_weight(punch: String, attack_time: float) -> float:
	if punch == "" or not Punches.has(punch):
		return 0.0
	var p := Punches.get_punch(punch)
	var dur := float(p["duration"])
	var load_end := float(p["windup"]) / dur
	var live_end := (float(p["windup"]) + float(p["active"])) / dur
	var u := clampf(attack_time / maxf(dur, 0.01), 0.0, 1.0)
	var ext := 0.0
	var arrive := load_end + (live_end - load_end) * 0.35
	var hold := load_end + (live_end - load_end) * 0.75
	if u < load_end:
		ext = 0.2 * (u / maxf(load_end, 0.001))
	elif u < arrive:
		ext = lerpf(0.25, 1.0, (u - load_end) / maxf(arrive - load_end, 0.001))
	elif u < hold:
		ext = 1.0
	else:
		ext = maxf(0.0, 1.0 - (u - hold) / 0.30)
	var coil: float = 1.0 - clampf(u / maxf(load_end, 0.001), 0.0, 1.0)
	return float(p["transfer"]) * (ext * 0.95 - coil * 0.3)

func _horizontal_speed() -> float:
	return Vector2(fighter.velocity.x, fighter.velocity.z).length()

func _movement_lean() -> Vector2:
	var local := fighter.global_basis.inverse() * fighter.velocity
	return Vector2(clampf(local.x / 2.2, -1.0, 1.0), clampf(local.z / 2.2, -1.0, 1.0))

func _base(index: int) -> Quaternion:
	if index < 0:
		return Quaternion.IDENTITY
	var current := skeleton.get_bone_pose_rotation(index)
	var previous: Quaternion = applied.get(index, Quaternion.IDENTITY)
	return current * previous.inverse()

func _write(index: int, value: Quaternion) -> void:
	if index < 0:
		return
	skeleton.set_bone_pose_rotation(index, value)
	applied[index] = value

func _write_add(index: int, delta: Quaternion) -> void:
	if index < 0:
		return
	var base := _base(index)
	_write(index, base * delta)
