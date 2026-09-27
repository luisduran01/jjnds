extends RefCounted
class_name ActiveRagdollController

# Deliberately PD-driven rather than PhysicalBone3D: two fighters need stable,
# deterministic animation contact at 60 Hz; PhysicsBones add joint jitter and
# broadphase cost before the game has per-bone collision meshes.

const BONES := ["Spine","Chest","Neck","Head","LeftUpperArm","LeftForeArm","RightUpperArm","RightForeArm"]
var offsets := {}
var angular_velocity := {}

func _init() -> void:
	reset()

func reset() -> void:
	offsets.clear()
	angular_velocity.clear()
	for bone in BONES:
		offsets[bone]=Vector3.ZERO
		angular_velocity[bone]=Vector3.ZERO

func apply_contact(zone: String, contact_position: Vector3, glove_velocity: Vector3, attacker_mass: float, guard_absorption: float, drive: float) -> void:
	var primary="Head" if zone=="head" else "Chest"
	var direction=glove_velocity.normalized()
	var axis=direction.cross(Vector3.UP)
	if axis.length_squared()<.001: axis=Vector3.RIGHT
	var leverage=clampf(absf(contact_position.y-(1.70 if zone=="head" else 1.35))+.55,.55,1.25)
	var impulse=axis.normalized()*glove_velocity.length()*attacker_mass*.00023*(1.0-clampf(guard_absorption,0.0,.85))*leverage/maxf(.35,drive)
	angular_velocity[primary]=angular_velocity[primary]+impulse
	offsets[primary]=offsets[primary]+impulse*.45
	var parent="Neck" if primary=="Head" else "Spine"
	angular_velocity[parent]=angular_velocity[parent]+impulse*.38
	offsets[parent]=offsets[parent]+impulse*.12

func step(delta: float, drive: float) -> void:
	var spring=22.0*drive
	var damping=8.0+drive*5.0
	for bone in BONES:
		var velocity: Vector3=angular_velocity[bone]
		var offset: Vector3=offsets[bone]
		velocity+=(-offset*spring-velocity*damping)*delta
		offset+=velocity*delta
		angular_velocity[bone]=velocity.clampf(-.65,.65)
		offsets[bone]=offset.clampf(-.55,.55)

func offset_for(bone: String) -> Vector3:
	return offsets.get(bone,Vector3.ZERO)
