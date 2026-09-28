extends SceneTree

const Support = preload("res://boxing/tests/test_support.gd")
var failures := 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("TEST FAILED: " + message)

func _initialize() -> void:
	var types = load("res://boxing/combat/combat_types.gd")
	check(types != null, "CombatTypes exists")
	if types:
		check(types.RangeBand.keys() == ["OUT_OF_RANGE", "LONG", "MID", "POCKET", "TOO_CLOSE"], "range enum contract")
		check(types.ContactResult.keys() == ["MISS", "GRAZE", "BLOCKED", "PARTIAL", "CLEAN", "COUNTER", "HEAVY_CLEAN"], "contact enum contract")
		check(types.ActionKind.keys() == ["NONE", "MOVE", "ATTACK", "DEFEND", "FEINT", "PIVOT", "CLINCH_BREAK"], "action enum contract")
		var hit = types.HitData.create(11, 22, 7, &"cross", &"head", Vector3(1, 2, 3), Vector3(4, 5, 6), 0.85, &"block_high")
		check(hit == {
			"attacker_id": 11, "victim_id": 22, "attack_id": 7,
			"punch": &"cross", "zone": &"head", "position": Vector3(1, 2, 3),
			"velocity": Vector3(4, 5, 6), "accuracy": 0.85, "defense": &"block_high"
		}, "HitData preserves every field")
		var snapshot = types.CombatSnapshot.create()
		check(snapshot.health == 100.0 and snapshot.energy == 100.0 and snapshot.guard == 100.0, "snapshot uses conservative resources")
		check(snapshot.distance == INF and snapshot.range_band == types.RangeBand.OUT_OF_RANGE, "snapshot defaults out of range")
		check(Support.check_finite_vector(snapshot.position) and Support.check_finite_vector(snapshot.velocity), "snapshot vectors are finite")
	print("CONTRACT TEST FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
