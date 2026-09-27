extends RefCounted
class_name CombatTypes

enum RangeBand { OUT_OF_RANGE, LONG, MID, POCKET, TOO_CLOSE }
enum ContactResult { MISS, GRAZE, BLOCKED, PARTIAL, CLEAN, COUNTER, HEAVY_CLEAN }
enum ActionKind { NONE, MOVE, ATTACK, DEFEND, FEINT, PIVOT, CLINCH_BREAK }

class HitData:
	extends RefCounted

	static func create(
		attacker_id: int,
		victim_id: int,
		attack_id: int,
		punch: StringName,
		zone: StringName,
		position: Vector3,
		velocity: Vector3,
		accuracy: float,
		defense: StringName
	) -> Dictionary:
		return {
			"attacker_id": attacker_id,
			"victim_id": victim_id,
			"attack_id": attack_id,
			"punch": punch,
			"zone": zone,
			"position": position,
			"velocity": velocity,
			"accuracy": accuracy,
			"defense": defense,
		}

class CombatSnapshot:
	extends RefCounted

	static func create(values: Dictionary = {}) -> Dictionary:
		var snapshot := {
			"fighter_id": 0,
			"state": 0,
			"health": 100.0,
			"energy": 100.0,
			"fatigue": 0.0,
			"guard": 100.0,
			"head_damage": 0.0,
			"body_damage": 0.0,
			"stun": 0.0,
			"balance": 100.0,
			"position": Vector3.ZERO,
			"velocity": Vector3.ZERO,
			"facing": Vector3.FORWARD,
			"distance": INF,
			"range_band": RangeBand.OUT_OF_RANGE,
			"near_ropes": false,
			"near_corner": false,
			"exposure": &"",
		}
		for key in values:
			if snapshot.has(key):
				snapshot[key] = values[key]
		return snapshot
