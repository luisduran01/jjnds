extends RefCounted

static func from_stats(height_cm: float, reach_cm: float, weight_lb: float) -> Dictionary:
	var profile := {}
	profile.height_scale = clampf(height_cm / 180.0,.90,1.10)
	var expected_reach = height_cm * 1.01
	profile.arm_scale = clampf(reach_cm / expected_reach,.88,1.18)
	profile.leg_scale = clampf(profile.height_scale * (2.0-profile.arm_scale),.90,1.10)
	var mass = clampf((weight_lb-147.0)/100.0,-.35,.55)
	profile.torso_width = clampf(1.0+mass*.24,.92,1.14)
	profile.torso_depth = clampf(1.0+mass*.18,.94,1.11)
	profile.muscle_mass = clampf(1.0+mass*.30,.90,1.18)
	profile.head_scale = clampf(1.0+(profile.height_scale-1.0)*.18-mass*.04,.96,1.04)
	return profile
