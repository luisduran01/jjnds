extends RefCounted
class_name ActiveRagdollController

# Deliberately PD-driven rather than PhysicalBone3D: two fighters need stable,
# deterministic animation contact at 60 Hz; PhysicsBones add joint jitter and
# broadphase cost before the game has per-bone collision meshes.
#
# Two independent layers, both applied additively after the AnimationTree:
#   reaction : integrated spring impulse from a landed punch, always returns to
#              the base pose on its own.
#   drive    : procedural punch chain (rear foot -> hip), a pure function of the
#              attack phase, so it can never accumulate and is exactly zero
#              outside an attack.

const ReachProfile = preload("res://boxing/characters/reach_profile.gd")
const Punches = preload("res://boxing/combat/punches.gd")

const UPPER_BONES := ["Spine", "Chest", "Neck", "Head", "LeftUpperArm", "LeftForeArm", "RightUpperArm", "RightForeArm"]
# Lower body is driven only in yaw: a pure twist cannot lower or sink a planted
# foot, while a pitch would.
const LOWER_BONES := ["Hips", "LeftThigh", "RightThigh"]
const BONES := UPPER_BONES + LOWER_BONES

# Hard per-bone ceilings, in radians. The head may travel furthest; the pelvis
# is the anchor of the whole body and stays subtle.
const LIMITS := {
	"Hips": 0.20, "LeftThigh": 0.24, "RightThigh": 0.24,
	"Spine": 0.38, "Chest": 0.44, "Neck": 0.50, "Head": 0.62,
	"LeftUpperArm": 0.34, "LeftForeArm": 0.34,
	"RightUpperArm": 0.34, "RightForeArm": 0.34,
}
# How hard the spring snaps back from an injected reaction.
const SNAP := 6.0
# Rear-foot pivot: the planted legs counter-rotate most of the pelvis twist.
const LEG_COUNTER := 0.72

var offsets := {}
var angular_velocity := {}
var drive := {}

func _init() -> void:
	reset()

func reset() -> void:
	offsets.clear()
	angular_velocity.clear()
	drive.clear()
	for bone in BONES:
		offsets[bone] = Vector3.ZERO
		angular_velocity[bone] = Vector3.ZERO
		drive[bone] = Vector3.ZERO

func clear_drive() -> void:
	for bone in BONES:
		drive[bone] = Vector3.ZERO

# Peak angular travel, in radians, for one landed impact.
func reaction_angle(punch: String, glove_velocity: Vector3, attacker_mass: float, guard_absorption: float, accuracy: float) -> float:
	return ReachProfile.reaction_angle(punch, glove_velocity.length(), attacker_mass, guard_absorption, accuracy)

func apply_contact(zone: String, contact_position: Vector3, glove_velocity: Vector3, attacker_mass: float, guard_absorption: float, drive_factor: float, punch: String = "", accuracy: float = 1.0) -> void:
	var primary := "Head" if zone == "head" else "Chest"
	var direction := glove_velocity.normalized()
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	var reaction := ReachProfile.reaction_for(punch)
	# Torque axis: lateral hits roll the head, straight hits pitch it back, and a
	# degenerate vertical hit (uppercut) falls back to the lateral axis so the
	# head snaps upward instead of vanishing.
	var axis := direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var spin: float = reaction.get("spin", 0.0)
	if absf(spin) > 0.0001:
		axis = (axis + direction * spin).normalized()
	var rise: float = reaction.get("rise", 0.0)
	if absf(rise) > 0.0001:
		axis = (axis + Vector3.RIGHT * rise).normalized()
	var reference_y := 1.70 if zone == "head" else 1.35
	var leverage := clampf(absf(contact_position.y - reference_y) + 0.55, 0.55, 1.25)
	var angle := reaction_angle(punch, glove_velocity, attacker_mass, guard_absorption, accuracy)
	var impulse := axis * angle * leverage / maxf(0.35, drive_factor)
	offsets[primary] = clampv(offsets[primary] + impulse, primary)
	angular_velocity[primary] = clampv(angular_velocity[primary] + impulse * SNAP, primary)
	var torso_share: float = reaction.get("torso", 0.45)
	var parent := "Neck" if primary == "Head" else "Spine"
	var parent_impulse := impulse * torso_share * 0.55
	offsets[parent] = clampv(offsets[parent] + parent_impulse, parent)
	angular_velocity[parent] = clampv(angular_velocity[parent] + parent_impulse * SNAP, parent)

# Procedural punch chain for the lower body: the rear foot pivots the pelvis and
# the planted legs take the twist back out, so the feet never slide or sink.
# Driven from the attack phase, therefore accumulation-free.
func set_punch_drive(punch: String, progress: float, intensity: float) -> void:
	clear_drive()
	if progress < 0.0 or progress > 1.0:
		return
	var chain := ReachProfile.chain_for(punch)
	# Hand authority comes from the punch table, never from the name's spelling.
	var side: int = Punches.DATA[punch][5] if Punches.DATA.has(punch) else 1
	var sign := -1.0 if side == 0 else 1.0
	# weight: rear foot -> hip, the slowest and heaviest link in the chain
	var weight := float(chain["weight"]) * ReachProfile.ramp(progress, 0.06, 0.62) * intensity
	# yaw only: a pure pelvis twist cannot lower or sink a planted foot, and being
	# a function of the attack phase it returns to the base pose exactly.
	var yaw := sign * 0.17 * weight
	drive["Hips"] = Vector3.UP * yaw
	drive["LeftThigh"] = Vector3.UP * -yaw * LEG_COUNTER
	drive["RightThigh"] = Vector3.UP * -yaw * LEG_COUNTER

func clampv(value: Vector3, bone: String) -> Vector3:
	var limit: float = LIMITS.get(bone, 0.4)
	return value.clampf(-limit, limit)

func step(delta: float, drive_factor: float) -> void:
	var spring := 22.0 * drive_factor
	var damping := 8.0 + drive_factor * 5.0
	for bone in BONES:
		var velocity: Vector3 = angular_velocity[bone]
		var offset: Vector3 = offsets[bone]
		velocity += (-offset * spring - velocity * damping) * delta
		offset += velocity * delta
		angular_velocity[bone] = velocity.clampf(-0.65, 0.65)
		offsets[bone] = clampv(offset, bone)

func offset_for(bone: String) -> Vector3:
	return offsets.get(bone, Vector3.ZERO) + drive.get(bone, Vector3.ZERO)

func reaction_for(bone: String) -> Vector3:
	return offsets.get(bone, Vector3.ZERO)

func drive_for(bone: String) -> Vector3:
	return drive.get(bone, Vector3.ZERO)
