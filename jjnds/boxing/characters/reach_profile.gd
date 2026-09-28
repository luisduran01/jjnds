extends RefCounted
class_name ReachProfile

# Single source of truth for arm geometry, punch reach and impact reaction.
#
# Why this exists: the rig ships short arms (0.480 m shoulder->wrist on a
# ~1.82 m stature, i.e. ~78% of human proportion), so a boxing range built on
# raw bone length falls short. The fix is deliberately NOT "stretch the model":
# the rig is only normalised to a capped, still-human proportion and the rest of
# the reach is bought with mechanics (step, weight, torso, shoulder, extension).

# Human reference: shoulder -> wrist is ~0.34 of standing stature.
const ANATOMICAL_ARM_RATIO := 0.34
# Head bone origin sits at ~0.934 of stature on this rig.
const HEAD_ORIGIN_STATURE_RATIO := 0.934
# Naturalisation floor / ceiling for the skinned limb. Above the ceiling the
# arm mesh reads as rubber, so mechanics must pay for the remaining range.
const MIN_LENGTHEN := 0.90
const MAX_LENGTHEN := 1.15
# Per-boxer variation (body_profile.arm_scale) rides on top of the
# naturalisation but the combined bone scale stays inside this ceiling.
const MAX_BONE_SCALE := 1.22
const GLOVE_RADIUS := 0.13

# Per-punch kinetic chain. `reach` is the share of the resolved arm length the
# punch may spend; it can never exceed 1.0, because aiming past the bone chain
# would lock the elbow while the wrist fell short of the target. Everything the
# arm cannot buy is paid by the chain, in this order:
#   step -> weight (rear foot / hips) -> torso -> shoulder -> lean -> extension
# A jab is shoulder + step dominant; a cross is hip + torso dominant, which is
# why the cross genuinely out-ranges the jab without a longer arm.
const CHAIN := {
	"jab": {"reach": 0.94, "step": 0.38, "weight": 0.22, "torso": 0.24, "shoulder": 0.52, "lean": 0.28, "rise": 0.05},
	"cross": {"reach": 1.00, "step": 0.30, "weight": 0.90, "torso": 0.68, "shoulder": 0.62, "lean": 0.46, "rise": 0.06},
	"body_jab": {"reach": 0.88, "step": 0.44, "weight": 0.24, "torso": 0.22, "shoulder": 0.52, "lean": 0.34, "rise": -0.30},
	"body_cross": {"reach": 0.96, "step": 0.38, "weight": 0.88, "torso": 0.60, "shoulder": 0.58, "lean": 0.40, "rise": -0.32},
	"left_hook": {"reach": 0.74, "step": 0.48, "weight": 0.66, "torso": 0.84, "shoulder": 0.30, "lean": 0.20, "rise": 0.04},
	"right_hook": {"reach": 0.76, "step": 0.46, "weight": 0.72, "torso": 0.88, "shoulder": 0.30, "lean": 0.22, "rise": 0.04},
	# A body hook is a close-range shot: the drop comes from the target height,
	# not from spine pitch, or it would out-reach the head hook it should be under.
	"body_hook": {"reach": 0.65, "step": 0.50, "weight": 0.66, "torso": 0.72, "shoulder": 0.26, "lean": 0.20, "rise": -0.34},
	"left_uppercut": {"reach": 0.58, "step": 0.34, "weight": 0.58, "torso": 0.34, "shoulder": 0.18, "lean": 0.16, "rise": 0.34},
	"right_uppercut": {"reach": 0.60, "step": 0.32, "weight": 0.62, "torso": 0.36, "shoulder": 0.18, "lean": 0.18, "rise": 0.36},
}

# Per-punch impact reaction. A full clean cross is the reference hit (~26 deg of
# head travel) and every other family is scaled from it, so a jab cannot rattle
# a head like a hook. `spin` biases the torque axis, `rise` lifts an uppercut
# into an upward snap, `torso` shares the impulse into the spine chain.
const REACTION := {
	"jab": {"scale": 0.30, "spin": 0.05, "rise": 0.00, "torso": 0.34},
	"cross": {"scale": 1.00, "spin": 0.10, "rise": 0.00, "torso": 0.50},
	"body_jab": {"scale": 0.34, "spin": 0.05, "rise": -0.10, "torso": 0.40},
	"body_cross": {"scale": 0.92, "spin": 0.10, "rise": -0.12, "torso": 0.58},
	"left_hook": {"scale": 0.86, "spin": 0.55, "rise": 0.05, "torso": 0.46},
	"right_hook": {"scale": 0.90, "spin": 0.55, "rise": 0.05, "torso": 0.46},
	"body_hook": {"scale": 0.72, "spin": 0.45, "rise": -0.20, "torso": 0.62},
	"left_uppercut": {"scale": 0.82, "spin": -0.10, "rise": 0.60, "torso": 0.38},
	"right_uppercut": {"scale": 0.86, "spin": -0.10, "rise": 0.62, "torso": 0.38},
}

# Reference hit used to normalise the impulse: a clean, well-timed cross
# thrown at NOMINAL_SPEED by NOMINAL_MASS reaches REFERENCE_REACTION_DEG.
const REFERENCE_REACTION_DEG := 26.0
const NOMINAL_SPEED := 4.5
const NOMINAL_MASS := 80.0
# A perfect counter on a tired chin tops out here (~34 deg) so the neck never folds.
const MAX_REACTION_RAD := 0.60

static func chain_for(punch: String) -> Dictionary:
	return CHAIN.get(punch, CHAIN["cross"])

# Ordered ramp: 0 before `start`, 1 after `start + span`, smooth between. Used so
# every punch fires its kinetic chain in order instead of moving all at once.
static func ramp(value: float, start: float, span: float) -> float:
	if span <= 0.0:
		return 1.0 if value >= start else 0.0
	return smoothstep(start, start + span, value)

static func reaction_for(punch: String) -> Dictionary:
	return REACTION.get(punch, REACTION["cross"])

# Reads the real arm geometry out of the imported rig instead of trusting
# constants; the whole reach model hangs off these numbers.
static func measure(skeleton: Skeleton3D) -> Dictionary:
	var base := {"upper": 0.25, "lower": 0.23, "total": 0.48, "stature": 1.82, "shoulder_x": 0.21}
	if skeleton == null:
		return base
	for side in ["Left", "Right"]:
		var ua := skeleton.find_bone(side + "UpperArm")
		var fa := skeleton.find_bone(side + "ForeArm")
		var hd := skeleton.find_bone(side + "Hand")
		if ua < 0 or fa < 0 or hd < 0:
			continue
		var shoulder := skeleton.get_bone_global_rest(ua).origin
		var elbow := skeleton.get_bone_global_rest(fa).origin
		var wrist := skeleton.get_bone_global_rest(hd).origin
		var upper := shoulder.distance_to(elbow)
		var lower := elbow.distance_to(wrist)
		if upper <= 0.0 or lower <= 0.0:
			continue
		base["upper"] = upper
		base["lower"] = lower
		base["total"] = upper + lower
		base["shoulder_x"] = absf(shoulder.x)
		break
	var head := skeleton.find_bone("Head")
	if head >= 0:
		var head_y := skeleton.get_bone_global_rest(head).origin.y
		if head_y > 0.1:
			base["stature"] = head_y / HEAD_ORIGIN_STATURE_RATIO
	return base

# Resolves the arm geometry actually used by the pose solver, the bone scale and
# the reach diagnostics, so all three can never disagree again.
static func resolve(base: Dictionary, arm_scale: float, height_scale: float) -> Dictionary:
	var base_total: float = base.get("total", 0.48)
	var stature: float = base.get("stature", 1.82)
	var anatomical := ANATOMICAL_ARM_RATIO * stature
	var naturalise := anatomical / maxf(0.01, base_total)
	var lengthen := clampf(naturalise, MIN_LENGTHEN, MAX_LENGTHEN)
	var bone_scale := clampf(lengthen * maxf(0.01, arm_scale), MIN_LENGTHEN, MAX_BONE_SCALE)
	var ratio := base_total / maxf(0.01, base.get("upper", 0.25) + base.get("lower", 0.23))
	return {
		"upper": base.get("upper", 0.25) * bone_scale,
		"lower": base.get("lower", 0.23) * bone_scale,
		"base_total": base_total,
		"total": base_total * bone_scale,
		"bone_scale": bone_scale,
		"lengthen": lengthen,
		"naturalise": naturalise,
		"height_scale": height_scale,
		"world_total": base_total * bone_scale * height_scale,
		"anatomical": anatomical,
		"shoulder_x": base.get("shoulder_x", 0.21),
		"ratio": ratio,
	}

# Extension limit for one punch, in metres, along the arm's own direction.
static func extension_for(reach: Dictionary, punch: String) -> float:
	var chain := chain_for(punch)
	return float(reach.get("total", 0.48)) * float(chain.get("reach", 1.0))

# Peak angular travel for one landed impact, in radians, expressed from a degree
# target so calibration stays legible. Clamped so a perfect counter cannot fold
# the neck backwards.
static func reaction_angle(punch: String, glove_speed: float, attacker_mass: float, guard_absorption: float, accuracy: float) -> float:
	var reaction := reaction_for(punch)
	var speed_term := clampf(glove_speed / NOMINAL_SPEED, 0.55, 1.65)
	var mass_term := clampf(attacker_mass / NOMINAL_MASS, 0.80, 1.25)
	var guard_term := 1.0 - clampf(guard_absorption, 0.0, 0.85)
	var quality := clampf(0.62 + accuracy * 0.38, 0.62, 1.0)
	var angle := deg_to_rad(REFERENCE_REACTION_DEG) * float(reaction["scale"]) * speed_term * mass_term * guard_term * quality
	return clampf(angle, 0.0, MAX_REACTION_RAD)
