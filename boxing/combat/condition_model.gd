extends RefCounted
class_name ConditionModel

const Types = preload("res://boxing/combat/combat_types.gd")
const ContactResult = Types.ContactResult
enum Activity { RESTING, MOVING, ATTACKING, DEFENDING, HURT }

var max_energy := 100.0
var health := 100.0
var energy := 100.0
var fatigue := 0.0
var guard := 100.0
var head_damage := 0.0
var body_damage := 0.0
var stun := 0.0
var balance := 100.0
var recovery_stat := 60.0
var chin := 1.0
var body_resistance := 1.0
var chain_pressure := 0.0

func configure(stats: Dictionary) -> void:
	max_energy = maxf(1.0, float(stats.get("energy", 100.0)))
	energy = max_energy
	recovery_stat = clampf(float(stats.get("recovery", 60.0)), 1.0, 100.0)
	chin = maxf(0.1, float(stats.get("chin", 1.0)))
	body_resistance = maxf(0.1, float(stats.get("body_resistance", 1.0)))

func can_spend(cost: float) -> bool:
	return energy >= maxf(0.0, cost)

func spend(cost: float, intensity: float, connected: bool) -> void:
	var safe_cost := maxf(0.0, cost)
	energy = maxf(0.0, energy - safe_cost)
	chain_pressure = minf(1.0, chain_pressure + 0.18)
	var whiff_factor := 1.12 if not connected else 1.0
	fatigue = minf(100.0, fatigue + safe_cost * 0.16 * maxf(0.0, intensity) * whiff_factor * (1.0 + chain_pressure))

func tick(delta: float, activity: int) -> void:
	var safe_delta := maxf(0.0, delta)
	if safe_delta == 0.0:
		return
	chain_pressure = maxf(0.0, chain_pressure - safe_delta * 0.28)
	if activity == Activity.RESTING or activity == Activity.MOVING:
		var body_factor := clampf(1.0 - body_damage / 140.0, 0.25, 1.0)
		var activity_factor := 1.0 if activity == Activity.RESTING else 0.45
		energy = minf(max_energy, energy + safe_delta * (2.0 + recovery_stat * 0.055) * body_factor * activity_factor)
		fatigue = maxf(0.0, fatigue - safe_delta * 0.65 * body_factor)
	guard = minf(100.0, guard + safe_delta * (2.0 if activity == Activity.DEFENDING else 5.0))
	stun = maxf(0.0, stun - safe_delta * 4.0)
	balance = minf(100.0, balance + safe_delta * 7.0)

func apply_hit(hit: Dictionary, result: int, damage: float) -> Dictionary:
	var safe_damage := maxf(0.0, damage)
	if result == ContactResult.MISS:
		return {"damage":0.0,"stun_added":0.0,"balance_lost":0.0}
	if result == ContactResult.BLOCKED:
		guard = maxf(0.0, guard - safe_damage * 1.5)
		energy = maxf(0.0, energy - safe_damage * 0.35)
		return {"damage":0.0,"stun_added":0.0,"balance_lost":safe_damage * 0.1}
	var zone: StringName = hit.get("zone", &"head")
	var applied := safe_damage / (body_resistance if zone == &"body" else chin)
	health = maxf(0.0, health - applied)
	if zone == &"body":
		body_damage += applied
		energy = maxf(0.0, energy - applied * 1.1)
	else:
		head_damage += applied
	var stun_added := applied * (1.45 if result in [ContactResult.COUNTER, ContactResult.HEAVY_CLEAN] else 1.0)
	stun += stun_added
	var balance_lost := applied * (1.35 if result == ContactResult.HEAVY_CLEAN else 0.8)
	balance = maxf(0.0, balance - balance_lost)
	return {"damage":applied,"stun_added":stun_added,"balance_lost":balance_lost}

func rest(seconds: float, treatment: StringName = &"") -> Dictionary:
	var cap := 25.0 if treatment == &"recover_stamina" else 18.0
	var recovered := minf(cap, maxf(0.0, seconds) * 0.3)
	var before := energy
	energy = minf(max_energy, energy + recovered)
	stun = maxf(0.0, stun - minf(12.0, maxf(0.0, seconds) * 0.2))
	balance = minf(100.0, balance + minf(20.0, maxf(0.0, seconds) * 0.3))
	return {"energy_recovered":energy - before,"treatment":treatment}

func snapshot() -> Dictionary:
	return {
		"health":health, "energy":energy, "fatigue":fatigue, "guard":guard,
		"head_damage":head_damage, "body_damage":body_damage, "stun":stun,
		"balance":balance,
	}
