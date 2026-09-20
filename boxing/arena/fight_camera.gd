extends Camera3D

var fight
var shake=0.0
var clock=0.0
var focus=Vector3(0,1,0)

func _ready() -> void:
	current=true
	fov=46
	position=Vector3(5,3.1,6)

func _process(delta: float) -> void:
	if not fight or not fight.player: return
	clock+=delta
	var a: Vector3=fight.player.global_position
	var b: Vector3=fight.enemy.global_position
	var midpoint=(a+b)*.5+Vector3(0,1,0)
	var separation=a.distance_to(b)
	var axis=(b-a).normalized()
	var side=Vector3(-axis.z,0,axis.x)
	if side.z<0: side=-side
	# Fixed hemisphere and slow orbit keep screen orientation stable.
	var offset=(side*.65+Vector3(.25,0,1)).normalized()
	var distance=clampf(3.25+separation*.72,4.0,8.2)
	if fight.down_fighter:
		midpoint=fight.down_fighter.position+Vector3(0,.45,0)
		distance=4.3
	focus=focus.lerp(midpoint,1-exp(-delta*3.4))
	var desired=focus+offset*distance+Vector3(0,1.10,0)
	position=position.lerp(desired,1-exp(-delta*2.5))
	shake=move_toward(shake,0,delta*.35)
	look_at(focus+Vector3(sin(clock*51),cos(clock*43),0)*shake)
