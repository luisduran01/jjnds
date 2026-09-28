extends SceneTree

var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func _initialize() -> void:
	var script = load("res://boxing/combat/condition_model.gd")
	check(script != null, "ConditionModel exists")
	if script:
		var model = script.new()
		model.configure({"energy":100.0,"recovery":60.0,"chin":1.0,"body_resistance":1.0})
		model.spend(10.0, 1.0, false)
		check(model.energy == 90.0 and model.fatigue > 0.0, "whiff spends energy and adds fatigue")
		var first_fatigue: float = model.fatigue
		model.spend(10.0, 1.0, true)
		check(model.energy == 80.0 and model.fatigue > first_fatigue, "rapid connected punch accumulates fatigue")
		model.tick(2.0, model.Activity.RESTING)
		check(model.energy > 80.0, "passive rest restores energy")
		var before_recovery: float = model.energy
		model.apply_hit({"zone":&"body"}, model.ContactResult.CLEAN, 20.0)
		model.tick(2.0, model.Activity.RESTING)
		check(model.energy - before_recovery < 12.0, "body damage reduces recovery")
		var hit = model.apply_hit({"zone":&"head"}, model.ContactResult.COUNTER, 12.0)
		check(hit.stun_added > 12.0 and model.head_damage == 12.0, "head counter increases localized stun")
		var guard_before: float = model.guard
		model.apply_hit({"zone":&"head"}, model.ContactResult.BLOCKED, 10.0)
		check(model.guard < guard_before and model.head_damage == 12.0, "block depletes guard without head damage")
		var rested = model.rest(60.0, &"recover_stamina")
		check(rested.energy_recovered <= 25.0 and model.energy <= 100.0, "round rest is bounded")
		model.tick(-1.0, model.Activity.RESTING)
		var snapshot = model.snapshot()
		for key in ["health","energy","fatigue","guard","head_damage","body_damage","stun","balance"]:
			check(is_finite(snapshot[key]), "%s stays finite" % key)
	print("CONDITION TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
