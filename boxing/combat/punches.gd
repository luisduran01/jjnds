extends RefCounted

# duration, active start/end, damage, stamina, hand, trajectory
const DATA = {
	"jab": [0.42,0.12,0.23,5.5,7.0,0,"straight"],
	"cross": [0.54,0.17,0.30,9.0,11.0,1,"straight"],
	"left_hook": [0.62,0.22,0.36,11.0,14.0,0,"hook"],
	"right_hook": [0.66,0.23,0.38,12.0,15.0,1,"hook"],
	"left_uppercut": [0.62,0.22,0.35,12.0,15.0,0,"upper"],
	"right_uppercut": [0.68,0.24,0.39,13.0,16.0,1,"upper"],
	"body_jab": [0.47,0.14,0.26,6.0,8.0,0,"straight"],
	"body_cross": [0.57,0.18,0.32,9.0,11.0,1,"straight"],
	"body_hook": [0.65,0.23,0.38,11.0,14.0,0,"hook"]
}

static func damage(base: float, stamina: float, speed: float, accuracy: float, counter: bool, body: bool, blocked: bool) -> float:
	return base * lerpf(0.55,1.0,clampf(stamina/100.0,0,1)) * clampf(speed,0.65,1.25) * clampf(accuracy,0.6,1.0) * (1.45 if counter else 1.0) * (0.88 if body else 1.0) * (0.22 if blocked else 1.0)
