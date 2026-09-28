extends Node

enum Strategy { IDLE, APPROACH, OUTSIDE, MID_RANGE, INSIDE, ATTACK, COMBO, DEFEND, BLOCK, DODGE, COUNTER, RETREAT, HURT, STUNNED, KNOCKDOWN, KO, CUT_RING, CLINCH_BREAK }
const STYLES = {
	"Out Boxer": {"range":1.12,"pressure":.36,"counter":.45,"combo":2,"power":.15,"circle":.85},
	"Pressure Fighter": {"range":.77,"pressure":.82,"counter":.2,"combo":3,"power":.40,"circle":.35},
	"Counter Puncher": {"range":1.0,"pressure":.28,"counter":.85,"combo":2,"power":.3,"circle":.60},
	"Swarmer": {"range":.66,"pressure":.92,"counter":.12,"combo":4,"power":.2,"circle":.7},
	"Power Puncher": {"range":.84,"pressure":.64,"counter":.5,"combo":2,"power":.78,"circle":.22}
}
@export_enum("Out Boxer","Pressure Fighter","Counter Puncher","Swarmer","Power Puncher") var style = "Pressure Fighter"
var fighter
var strategy = Strategy.IDLE
var think_time = .2
var cooldown = .8
var chain: Array = []
var direction = 1.0
var observed_attack = ""
var rng = RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed=91273

func _physics_process(delta: float) -> void:
	if not fighter or not fighter.opponent: return
	if not fighter.fighting:
		fighter.move_input=Vector2.ZERO
		return
	think_time-=delta
	cooldown-=delta
	if think_time>0: return
	think_time=rng.randf_range(.13,.24)+fighter.fatigue.reaction_delay()
	decide()

func decide() -> void:
	var f=fighter
	var target=f.opponent
	var p=STYLES[style]
	if f.state in [f.State.DODGING,f.State.GET_UP]: return
	if f.state in [f.State.HURT,f.State.STUNNED,f.State.KNOCKDOWN,f.State.KO]:
		strategy=Strategy.HURT if f.state==f.State.HURT else Strategy.KNOCKDOWN if f.state==f.State.KNOCKDOWN else Strategy.KO if f.state==f.State.KO else Strategy.STUNNED
		chain.clear()
		return
	var distance: float=f.global_position.distance_to(target.global_position)
	var edge=maxf(absf(f.position.x),absf(f.position.z))>2.55
	if rng.randf()<.08: direction*=-1
	# A style's preferred range must never exceed what this fighter's own arm can
	# cover, or the AI plants itself outside its punches and swings at air.
	var arm_range: float = f.working_range()
	var desired: float=minf(p.range+(.2 if f.health<30 else 0),arm_range)
	f.move_input=Vector2(direction*p.circle*.45,0)
	if edge:
		var center: Vector3=f.global_basis.inverse()*(-f.position).normalized()
		f.move_input=Vector2(center.x,-center.z)
		strategy=Strategy.RETREAT
	elif f.stamina<25 or (f.health<25 and rng.randf()<.4):
		f.move_input.y=.85 if distance<1.6 else 0
		strategy=Strategy.RETREAT
		chain.clear()
	elif distance>desired+.16:
		# Cortar el ring: moverse en ángulo para acorralar en lugar de perseguir directo
		var to_target = (target.global_position - f.global_position).normalized()
		var lateral = Vector3(-to_target.z, 0, to_target.x)
		var corner_pos = target.global_position
		# Si el rival está huyendo y cerca de una esquina, cortar lateralmente
		var target_near_wall = absf(target.position.x) > 2.0 or absf(target.position.z) > 2.0
		if target_near_wall and rng.randf() < p.get("circle", 0.5):
			# Moverse en diagonal para cortar el ring
			var cut_dir = f.global_basis.inverse() * (to_target + lateral * 0.6).normalized()
			f.move_input = Vector2(cut_dir.x, -cut_dir.z) * p.pressure
			strategy = Strategy.CUT_RING
		else:
			f.move_input.y=-p.pressure
			f.move_input.x+=clampf(target.velocity.dot(f.global_basis.x)*.2,-.3,.3)
			strategy=Strategy.APPROACH
	elif distance<desired-.16:
		f.move_input.y=.65
		strategy=Strategy.OUTSIDE
	else:
		strategy=Strategy.INSIDE if distance<.8 else Strategy.MID_RANGE
	if f.state==f.State.ATTACKING: return
	if f.state==f.State.BLOCKING:
		f.defense=""
		f.set_state(f.State.IDLE)
	var incoming: String=target.current_punch
	if incoming!="" and observed_attack!=incoming and distance<1.35 and f.stamina>12:
		observed_attack=incoming
		if rng.randf()<.72:
			if rng.randf()<.3:
				f.dodge("dodge_left" if rng.randf()<.5 else "duck")
				strategy=Strategy.DODGE
			else:
				f.defense="block_body" if incoming.begins_with("body") else "block_high"
				f.set_state(f.State.BLOCKING,0,f.defense)
				strategy=Strategy.BLOCK
			return
	if incoming=="": observed_attack=""
	var punish: bool=target.recovery>.02 or (target.state==target.State.ATTACKING and target.attack_time>.26)
	if punish and distance<arm_range and rng.randf()<p.counter and f.stamina>18:
		# Counter with whatever actually reaches from here.
		var counter_punch: String="cross"
		if distance<=f.punch_envelope("left_hook"): counter_punch="left_hook"
		if distance<=f.punch_envelope("right_uppercut"): counter_punch="right_uppercut"
		if f.attack(counter_punch):
			strategy=Strategy.COUNTER
			cooldown=.7
		return
	if cooldown>0 or distance>arm_range or f.stamina<20: return
	if chain.is_empty():
		var straight_ok: bool=distance<=f.punch_envelope("jab")
		var hook_ok: bool=distance<=f.punch_envelope("left_hook")
		var upper_ok: bool=distance<=f.punch_envelope("right_uppercut")
		if not (straight_ok or hook_ok or upper_ok):
			# Nothing reaches from here: keep closing instead of throwing air.
			return
		# The jab always leads, at every range: it is the punch that sets up
		# everything else. Inside the pocket the follow-ups shorten instead of
		# replacing the lead.
		chain=["jab","cross"]
		if rng.randf()<p.power and straight_ok: chain=["body_jab","right_hook"]
		if distance<.80 and hook_ok: chain=["jab","body_hook","right_uppercut"]
		if p.combo>=3 and hook_ok: chain.append("left_hook")
		if p.combo>=4 and straight_ok: chain.append("body_cross")
		# Insertar amago ocasionalmente para decepcionar al rival
		if rng.randf() < 0.15 and chain.size() > 0:
			chain.insert(0, "feint_jab")
	var next: String=chain.pop_front()
	if next.begins_with("feint_"):
		var base = next.substr(6)
		f.feint(base)
		strategy = Strategy.ATTACK
		cooldown = rng.randf_range(0.3, 0.5)
		return
	if f.attack(next):
		strategy=Strategy.COMBO if not chain.is_empty() else Strategy.ATTACK
		cooldown=.47 if not chain.is_empty() else rng.randf_range(.65,1.3)
	else: cooldown=.2
