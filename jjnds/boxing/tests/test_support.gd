extends RefCounted
class_name CombatTestSupport

static func check_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

