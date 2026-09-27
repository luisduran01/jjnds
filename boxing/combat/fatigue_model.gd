extends RefCounted
class_name TacticalFatigue

var max_energy := 100.0
var energy := 100.0
var fatigue := 0.0
var recovery_stat := 60.0
var chain_pressure := 0.0

func configure(capacity: float, recovery: float=60.0) -> void:
	max_energy=maxf(1.0,capacity)
	energy=max_energy
	recovery_stat=clampf(recovery,1.0,100.0)
	fatigue=0.0
	chain_pressure=0.0

func spend(cost: float, intensity: float=1.0) -> void:
	var scaled=maxf(0.0,cost)*maxf(.5,intensity)
	energy=maxf(0.0,energy-scaled)
	chain_pressure=minf(1.0,chain_pressure+.28*intensity)
	fatigue=minf(100.0,fatigue+scaled*.42+chain_pressure*4.0)

# Sustained cost (holding a guard, carrying body damage) without the burst
# fatigue that spend() charges for a single explosive action.
func drain(amount: float) -> void:
	energy=maxf(0.0,energy-maxf(0.0,amount))

func tick(delta: float, guarding: bool) -> void:
	chain_pressure=maxf(0.0,chain_pressure-delta*(.55 if guarding else 1.25))
	var recovery=(7.0+recovery_stat*.09)*(0.55 if guarding else 1.0)*(1.0-fatigue/260.0)
	energy=minf(max_energy,energy+delta*recovery)
	fatigue=maxf(0.0,fatigue-delta*(1.15+recovery_stat*.018)*(1.35 if not guarding else .55))

func energy_ratio() -> float:
	return clampf(energy/max_energy,0.0,1.0)

func animation_factor() -> float:
	return clampf(lerpf(.62,1.0,energy_ratio())-fatigue*.0015,.55,1.0)

func drive_factor() -> float:
	return clampf(lerpf(.48,1.0,energy_ratio())-fatigue*.002,.40,1.0)

func guard_factor() -> float:
	return clampf(lerpf(.45,1.0,energy_ratio())-fatigue*.0025,.35,1.0)

func damage_factor() -> float:
	return clampf(lerpf(.55,1.0,energy_ratio())-fatigue*.001,.5,1.0)

func accuracy_factor() -> float:
	return clampf(lerpf(.62,1.0,energy_ratio())-fatigue*.0022,.52,1.0)

func reaction_delay() -> float:
	return clampf((1.0-energy_ratio())*.10+fatigue*.0018,0.0,.22)
