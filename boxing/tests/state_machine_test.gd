extends SceneTree

var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func _initialize() -> void:
	var script = load("res://boxing/combat/combat_state_machine.gd")
	check(script != null, "CombatStateMachine exists")
	if script:
		var machine = script.new()
		check(machine.request(machine.State.ATTACKING, 0.2, &"jab"), "neutral can attack")
		machine.tick(0.1)
		check(machine.state == machine.State.ATTACKING, "attack stays active through its recovery timer")
		machine.tick(0.1)
		check(machine.state == machine.State.IDLE, "attack recovers to neutral")

		machine.request(machine.State.ATTACKING, 1.0, &"cross")
		check(machine.request(machine.State.HURT, 0.3, &"head"), "hurt interrupts attack")
		check(machine.state == machine.State.HURT, "hurt transition applied")
		machine.request(machine.State.KO, 0.0, &"count_ten")
		check(not machine.request(machine.State.ATTACKING, 0.2, &"jab"), "KO rejects actions")

		machine.reset()
		var jab := {"kind": 2, "name": &"jab"}
		var cross := {"kind": 2, "name": &"cross"}
		check(machine.buffer(jab, 0.16), "first early action buffers")
		check(not machine.buffer(cross, 0.16), "repeated input cannot replace buffered action")
		check(machine.take_buffered() == jab, "buffered action is returned once")
		check(machine.take_buffered().is_empty(), "buffer is empty after consumption")
		machine.buffer(cross, 0.05)
		machine.tick(0.06)
		check(machine.take_buffered().is_empty(), "expired action cannot execute")

		check(machine.request(machine.State.ATTACKING, 0.01, &"missing_clip"), "unknown presentation reason cannot block state")
		machine.tick(-1.0)
		check(machine.state == machine.State.ATTACKING, "negative delta is clamped")
		machine.tick(0.02)
		check(machine.state == machine.State.IDLE, "unknown presentation reason returns to neutral")
	print("STATE MACHINE TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
