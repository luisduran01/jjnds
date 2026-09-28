extends "res://boxing/main.gd"

# Real fight end-to-end: main.tscn + AI + physics, with assertions instead of a
# bare "it finished" check. Guards the integration behaviour that unit tests
# cannot see: does the AI actually reach, do both zones get hit, is damage
# coherent, are reactions visible, does stamina really drain in a live fight.

var failures := 0
var elapsed := 0.0
var phase_visits: Dictionary = {}
var extra_brain
var report: Dictionary = {}

var hits: Array = []
var head_hits := {"player": 0, "enemy": 0}
var body_hits := {"player": 0, "enemy": 0}
var punches_used: Dictionary = {}
var max_reach_distance := 0.0
var max_reaction_deg := 0.0
var min_stamina := {"player": 100.0, "enemy": 100.0}
var max_fatigue := {"player": 0.0, "enemy": 0.0}
var sum_damage := 0.0
var blocked_hits := 0
var counter_hits := 0
var completed := false
var frame_count := 0
var fps_sum := 0.0
var finite_ok := true

func _ready() -> void:
	super._ready()
	hud.menu.hide()
	fight.round_time = 12
	fight.rest_time = 3
	fight.rounds_choice = "3"
	fight.player.is_player = false
	# Two contrasting styles so straights, hooks, uppercuts and body work all
	# appear in the same live fight.
	extra_brain = Brain.new()
	extra_brain.fighter = fight.player
	extra_brain.style = "Swarmer"
	add_child(extra_brain)
	brain.style = "Power Puncher"
	for boxer in [fight.player, fight.enemy]:
		boxer.hit_landed.connect(_on_hit)
	fight.begin()

func _on_hit(attacker, victim, info) -> void:
	var side := "player" if attacker == fight.player else "enemy"
	var zone: String = info.get("zone", "")
	punches_used[info.get("punch", "")] = true
	if zone == "head": head_hits[side] += 1
	else: body_hits[side] += 1
	if info.get("blocked", false): blocked_hits += 1
	if info.get("counter", false): counter_hits += 1
	sum_damage += float(info.get("damage", 0.0))
	# Reach envelope: a landed hit must sit inside what the rig can actually cover,
	# otherwise the AI is connecting through a range the character does not have.
	var gap: float = attacker.global_position.distance_to(victim.global_position)
	max_reach_distance = maxf(max_reach_distance, gap)
	hits.append({"punch": info.get("punch", ""), "zone": zone, "damage": info.get("damage", 0.0), "gap": gap, "reach": attacker.effective_reach})

func _process(delta: float) -> void:
	if completed: return
	elapsed += delta
	frame_count += 1
	fps_sum += Engine.get_frames_per_second()
	phase_visits[fight.Phase.keys()[fight.phase]] = true
	for pair in [["player", fight.player], ["enemy", fight.enemy]]:
		var key: String = pair[0]
		var boxer = pair[1]
		min_stamina[key] = minf(min_stamina[key], boxer.stamina)
		max_fatigue[key] = maxf(max_fatigue[key], boxer.fatigue.fatigue)
		# A reaction counts in the head OR the torso: a body hook folds the chest,
		# so measuring only the head would hide half the impact system.
		max_reaction_deg = maxf(max_reaction_deg, rad_to_deg(boxer.active_ragdoll.reaction_for("Head").length()))
		max_reaction_deg = maxf(max_reaction_deg, rad_to_deg(boxer.active_ragdoll.reaction_for("Chest").length()))
		if not (is_finite(boxer.global_position.x) and is_finite(boxer.global_position.y) and is_finite(boxer.global_position.z)):
			finite_ok = false
		if absf(boxer.position.x) > 4.0 or absf(boxer.position.z) > 4.0:
			finite_ok = false
	if fight.phase == fight.Phase.FIGHT_END or elapsed > 120:
		completed = true
		finish()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func finish() -> void:
	var total_hits: int = head_hits.player + head_hits.enemy + body_hits.player + body_hits.enemy
	report = {
		"complete": fight.phase == fight.Phase.FIGHT_END,
		"result": fight.result,
		"elapsed": elapsed,
		"round": fight.round_number,
		"phases": phase_visits.keys(),
		"player_throws": fight.player.thrown,
		"player_lands": fight.player.landed,
		"enemy_throws": fight.enemy.thrown,
		"enemy_lands": fight.enemy.landed,
		"head_hits": head_hits,
		"body_hits": body_hits,
		"punches": punches_used.keys(),
		"blocked": blocked_hits,
		"counters": counter_hits,
		"avg_damage": sum_damage / maxf(1.0, float(total_hits)),
		"max_reach_distance": max_reach_distance,
		"max_reaction_deg": max_reaction_deg,
		"min_stamina": min_stamina,
		"max_fatigue": max_fatigue,
		"avg_fps": fps_sum / maxi(1, frame_count),
	}
	FileAccess.open("res://boxing/tests/fight_e2e.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("E2E REPORT: ", report)

	# --- the fight itself ---
	check(report.complete, "real fight reaches FIGHT_END")
	for phase in ["ROUND_START", "FIGHTING", "ROUND_END", "REST", "FIGHT_END"]:
		check(phase_visits.has(phase), "real fight visits phase " + phase)
	check(fight.round_number == 3, "real fight reaches round 3")
	check(finite_ok, "no NaN positions and nobody leaves the ring")

	# --- the AI actually fights ---
	check(fight.player.thrown > 12 and fight.enemy.thrown > 12, "both fighters throw a real volume of punches")
	check(fight.player.landed > 0 and fight.enemy.landed > 0, "both fighters land")
	check(total_hits > 8, "the fight produces real contact")
	var p_prec: float = float(fight.player.landed) / maxf(1.0, float(fight.player.thrown))
	var e_prec: float = float(fight.enemy.landed) / maxf(1.0, float(fight.enemy.thrown))
	check(p_prec > 0.15 and p_prec < 0.98, "player precision is neither blind nor perfect (%.2f)" % p_prec)
	check(e_prec > 0.15 and e_prec < 0.98, "enemy precision is neither blind nor perfect (%.2f)" % e_prec)

	# --- HEAD / BODY both resolve, on both fighters ---
	check(head_hits.player > 0 and head_hits.enemy > 0, "head shots land on both fighters")
	check(body_hits.player > 0 and body_hits.enemy > 0, "body shots land on both fighters")
	check(punches_used.size() >= 3, "the AI uses several punch types, not one")

	# --- damage coherence (never inflated to pass a test) ---
	check(report.avg_damage > 1.6 and report.avg_damage < 8.0, "average damage per landed punch stays coherent (%.2f)" % report.avg_damage)
	check(blocked_hits > 0, "blocks actually absorb hits during a real fight")
	check(counter_hits > 0, "counter punches are recognised during a real fight")

	# --- reach envelope ---
	# A landed hit cannot exceed arm + glove + the largest hurtbox, plus lean.
	for hit in hits:
		var envelope: float = float(hit.reach) + 0.13 + 0.245 + 0.22
		check(float(hit.gap) <= envelope, "landed %s sits inside the reach envelope (gap %.2f vs %.2f)" % [hit.punch, hit.gap, envelope])

	# --- reactions survive the AnimationTree in a live fight ---
	check(max_reaction_deg > 2.0, "impact reactions are visible during a real fight (%.2f deg)" % max_reaction_deg)

	# --- stamina / fatigue work in a live fight ---
	check(min_stamina.player < 92.0 and min_stamina.enemy < 92.0, "punches really drain stamina in a fight")
	check(max_fatigue.player > 1.0 and max_fatigue.enemy > 1.0, "fatigue accumulates during a fight")
	check(fight.player.stamina >= 0.0 and fight.enemy.stamina >= 0.0, "stamina never goes negative")

	print("E2E FAILURES: ", failures)
	get_tree().quit(1 if failures > 0 else 0)
