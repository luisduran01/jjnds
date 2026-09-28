extends RefCounted
class_name ArmIK

static func solve(shoulder: Vector3, upper_length: float, lower_length: float, target: Vector3) -> Dictionary:
	var delta=target-shoulder
	var reach=maxf(.001,delta.length())
	var clamped=clampf(reach,absf(upper_length-lower_length)+.001,upper_length+lower_length-.001)
	var direction=delta.normalized() if reach>.001 else Vector3.FORWARD
	var elbow_distance=(upper_length*upper_length-lower_length*lower_length+clamped*clamped)/(2.0*clamped)
	var elbow_height=sqrt(maxf(.0,upper_length*upper_length-elbow_distance*elbow_distance))
	var pole=direction.cross(Vector3.UP)
	if pole.length_squared()<.001: pole=Vector3.RIGHT
	pole=pole.normalized()
	return {"target":shoulder+direction*clamped,"elbow":shoulder+direction*elbow_distance+pole*elbow_height,"clamped":reach!=clamped}
