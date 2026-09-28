extends SceneTree
# Regression: real glancing contacts must reduce health, never heal the victim.
const FighterScript = preload("res://boxing/characters/fighter.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var attacker = FighterScript.new()
	var victim = FighterScript.new()
	root.add_child(attacker)
	root.add_child(victim)
	attacker.set_physics_process(false)
	victim.set_physics_process(false)
	attacker.fighting = true
	victim.fighting = true
	var impacts: Array = []
	attacker.hit_landed.connect(func(_a, _v, info): impacts.append(info))
	var id := 1
	for punch in ["right_hook", "right_uppercut", "body_jab"]:
		for accuracy in [.35, .4, .5, .6, .65, .719, .72, 1.0]:
			victim.health = 100.0
			victim.head_damage = 0.0
			victim.body_damage = 0.0
			victim.stun = 0.0
			victim.knockdown_meter = 0.0
			victim.set_state(victim.State.IDLE)
			var zone := "body" if punch.begins_with("body") else "head"
			var accepted: bool = victim.receive_hit(attacker,punch,zone,1.0,accuracy,id)
			var amount: float = impacts.back().damage if not impacts.is_empty() else 0.0
			if not accepted or amount <= 0.0 or victim.health >= 100.0:
				failures += 1
				print("FAIL ",punch," accuracy=",accuracy," damage=",amount," health=",victim.health)
			var hp: float = victim.health
			if victim.receive_hit(attacker,punch,zone,1.0,accuracy,id) or victim.health != hp:
				failures += 1
				print("FAIL duplicate hit ",punch)
			id += 1
	attacker.free()
	victim.free()
	print("GLANCING CONTACT TEST FAILURES: ",failures)
	quit(1 if failures else 0)
