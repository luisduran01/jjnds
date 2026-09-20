extends CharacterBody3D

signal hit_landed(attacker, victim, info)
signal knocked_down(fighter)
signal state_changed(next)

enum State { IDLE, MOVING, ATTACKING, BLOCKING, DODGING, HURT, STUNNED, KNOCKDOWN, GET_UP, KO, VICTORY, DEFEAT }
const Punches = preload("res://boxing/combat/punches.gd")
const Animations = preload("res://boxing/characters/animation_factory.gd")
@export var is_player = false
@export var boxer_name = "ALONSO"
@export var team_color = Color("d94938")
var opponent: CharacterBody3D
var state = State.IDLE
var health = 100.0
var stamina = 100.0
var guard = 100.0
var head_damage = 0.0
var body_damage = 0.0
var stun = 0.0
var knockdown_meter = 0.0
var knockdowns = 0
var round_knockdowns = 0
var landed = 0
var thrown = 0
var round_quality = 0.0
var fighting = false
var move_input = Vector2.ZERO
var defense = ""
var current_punch = ""
var attack_time = 0.0
var attack_scale = 1.0
var attack_stamina = 100.0
var attack_id = 0
var recovery = 0.0
var combo_count = 0
var combo_window = 0.0
var state_time = 0.0
var buffered = ""
var buffer_life = 0.0
var hits_received: Dictionary = {}
var model: Node3D
var skeleton: Skeleton3D
var animation: Dictionary
var fist_points: Array[Node3D] = []
var fists: Array[Area3D] = []
var hurts: Array[Area3D] = []
var old_fists: Array[Vector3] = []
var fist_speed = 1.0
var attack_connected = false
var debug_shapes: Array[MeshInstance3D] = []

func _ready() -> void:
	collision_layer = 2
	collision_mask = 3
	var shape = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = .23
	capsule.height = 1.72
	shape.shape = capsule
	shape.position.y = .86
	add_child(shape)
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var packed = load("res://boxing/characters/boxer_rigged.glb") as PackedScene
	if packed == null:
		push_error("Rigged character was not imported")
		return
	var visual = packed.instantiate()
	model.add_child(visual)
	skeleton = find_skeleton(visual)
	animation = Animations.build(model,skeleton)
	for side in ["Left","Right"]:
		var attach = BoneAttachment3D.new()
		attach.name = side+"FistAttachment"
		skeleton.add_child(attach)
		attach.bone_name = side+"Hand"
		var point = Node3D.new()
		point.position.x = .065 if side == "Left" else -.065
		attach.add_child(point)
		fist_points.append(point)
		var fist = make_area(side+"FistHitbox",.13,4,8)
		add_child(fist)
		fists.append(fist)
		old_fists.append(Vector3.ZERO)
	for zone in ["head","body"]:
		var area = make_area(zone,.19 if zone=="head" else .245,8,0)
		area.set_meta("fighter",self)
		area.set_meta("zone",zone)
		add_child(area)
		hurts.append(area)
	# Team bands use original geometry with a subtle material tint on the opponent.
	for mesh in visual.find_children("*","MeshInstance3D",true,false):
		var material = mesh.get_active_material(0).duplicate() as StandardMaterial3D
		material.vertex_color_use_as_albedo=true
		material.albedo_color = Color.WHITE
		mesh.material_override = material
		if not is_player:
			var opponent_material=ShaderMaterial.new()
			opponent_material.shader=load("res://boxing/characters/opponent.gdshader")
			mesh.material_override=opponent_material

func find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child in node.get_children():
		var result = find_skeleton(child)
		if result: return result
	return null

func make_area(label: String,radius: float,layer: int,mask: int) -> Area3D:
	var area = Area3D.new()
	area.name = label
	area.collision_layer = layer
	area.collision_mask = mask
	area.monitoring = false
	var collision = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	collision.shape = sphere
	area.add_child(collision)
	var mesh = MeshInstance3D.new()
	var ball = SphereMesh.new()
	ball.radius = radius
	ball.height = radius*2
	mesh.mesh = ball
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1,.3,.1,.28) if layer==4 else Color(.1,1,.4,.24)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.visible = false
	area.add_child(mesh)
	debug_shapes.append(mesh)
	return area

func set_state(next: State,duration: float=0.0,clip: String="") -> void:
	if state==State.ATTACKING and next!=State.ATTACKING:
		current_punch=""
		if next!=State.IDLE:
			buffered=""
			buffer_life=0
	state = next
	state_time = duration
	if not animation.is_empty():
		var desired = clip if clip!="" else "guard"
		animation.playback.start(desired,true)
	state_changed.emit(next)

func can_act() -> bool:
	return fighting and state in [State.IDLE,State.MOVING,State.BLOCKING]

func attack(punch: String) -> bool:
	if not Punches.DATA.has(punch): return false
	if state==State.ATTACKING:
		buffered = punch
		buffer_life = .20
		return false
	if not can_act(): return false
	var data = Punches.DATA[punch]
	var cost: float = data[4]*(1.0+minf(combo_count,4)*.08)
	if stamina<cost: return false
	attack_stamina = stamina
	stamina -= cost
	combo_count = combo_count+1 if combo_window>0 else 1
	combo_window = 1.05
	attack_scale = lerpf(.64,1.0,stamina/100)
	attack_id += 1
	attack_time = 0
	attack_connected = false
	current_punch = punch
	thrown += 1
	defense = ""
	set_state(State.ATTACKING,0,punch)
	return true

func dodge(kind: String) -> void:
	if not can_act() or stamina<9: return
	stamina -= 9
	defense = kind
	set_state(State.DODGING,.5,kind)

func _physics_process(delta: float) -> void:
	if not skeleton: return
	state_time = maxf(0,state_time-delta)
	buffer_life = maxf(0,buffer_life-delta)
	combo_window = maxf(0,combo_window-delta)
	if combo_window<=0: combo_count=0
	if buffer_life<=0: buffered=""
	if is_player and fighting: read_input()
	if opponent and state not in [State.KNOCKDOWN,State.KO,State.GET_UP]:
		var flat = opponent.global_position-global_position
		flat.y=0
		if flat.length()>.1:
			rotation.y = lerp_angle(rotation.y,atan2(flat.x,flat.z),minf(1,delta*9))
	if state==State.ATTACKING:
		attack_time += delta*attack_scale
		animation.tree.set("parameters/ActionSpeed/scale",attack_scale)
		var d = Punches.DATA[current_punch]
		if attack_time>=d[0]:
			recovery = .15 if not attack_connected else .02
			set_state(State.IDLE)
			current_punch=""
			if buffered!="":
				var next=buffered
				buffered=""
				attack(next)
	elif state in [State.DODGING,State.HURT,State.STUNNED,State.GET_UP] and state_time<=0:
		defense=""
		set_state(State.IDLE)
	if state!=State.ATTACKING: animation.tree.set("parameters/ActionSpeed/scale",1.0)
	if state not in [State.KNOCKDOWN,State.KO,State.VICTORY,State.DEFEAT]:
		var speed = lerpf(1.1,2.1,health/100.0)*lerpf(.65,1.0,stamina/100.0)
		if state==State.ATTACKING: speed*=.48
		if state==State.BLOCKING: speed*=.56
		if state in [State.HURT,State.STUNNED,State.GET_UP]: speed*=.12
		var direction = global_basis*Vector3(move_input.x,0,-move_input.y)
		var desired = direction*speed if fighting else Vector3.ZERO
		velocity.x = move_toward(velocity.x,desired.x,delta*10)
		velocity.z = move_toward(velocity.z,desired.z,delta*10)
		velocity.y -= 9.8*delta
		move_and_slide()
		if state in [State.IDLE,State.MOVING]:
			state = State.MOVING if direction.length()>.1 else State.IDLE
	else:
		velocity=Vector3.ZERO
	animation.tree.set("parameters/Footwork/blend_position",move_input if fighting else Vector2.ZERO)
	var down = state in [State.KNOCKDOWN,State.KO,State.DEFEAT]
	var target_roll = -1.5 if down else 0.0
	model.rotation.x = lerp_angle(model.rotation.x,target_roll,minf(1,delta*5))
	model.position.y = lerpf(model.position.y,.17 if down else (-.20*sin((.5-state_time)*PI/.5) if state==State.DODGING and defense=="duck" else 0.0),minf(1,delta*10))
	if state!=State.ATTACKING and state not in [State.KNOCKDOWN,State.KO]:
		stamina = minf(100,stamina+delta*lerpf(14,6,clampf(body_damage/100,0,1))*(.6 if state==State.BLOCKING else 1.0))
	guard = minf(100,guard+delta*6)
	stun=maxf(0,stun-delta*8)
	knockdown_meter=maxf(0,knockdown_meter-delta*2.5)
	recovery=maxf(0,recovery-delta)
	update_hitboxes(delta)

func read_input() -> void:
	move_input=Input.get_vector("box_left","box_right","box_forward","box_back")
	if Input.is_action_pressed("box_guard") and can_act():
		var kind="block_body" if Input.is_action_pressed("box_body") else "block_high"
		if state!=State.BLOCKING or defense!=kind: set_state(State.BLOCKING,0,kind)
		defense=kind
	elif state==State.BLOCKING:
		defense=""
		set_state(State.IDLE)
	var body=Input.is_action_pressed("box_body")
	for name in ["jab","cross","left_hook","right_hook","left_uppercut","right_uppercut"]:
		if Input.is_action_just_pressed("box_"+name):
			attack(("body_jab" if name=="jab" else "body_cross" if name=="cross" else "body_hook") if body else name)
	for name in ["dodge_left","dodge_right","duck","weave","pivot_left","pivot_right"]:
		if Input.is_action_just_pressed("box_"+name): dodge(name)
	if state==State.DODGING and defense.begins_with("pivot"):
		move_input.x=-1 if defense=="pivot_left" else 1

func update_hitboxes(delta: float) -> void:
	skeleton.force_update_all_bone_transforms()
	var head = skeleton.find_bone("Head")
	var chest = skeleton.find_bone("Chest")
	hurts[0].global_position = skeleton.global_transform*(skeleton.get_bone_global_pose(head).origin+Vector3(0,.07,.015))
	hurts[1].global_position = skeleton.global_transform*(skeleton.get_bone_global_pose(chest).origin+Vector3(0,-.10,0))
	for hand in 2:
		var point = fist_points[hand].global_position
		fists[hand].global_position=point
		var effective=false
		if fighting and state==State.ATTACKING:
			var d=Punches.DATA[current_punch]
			effective=hand==d[5] and attack_time>=d[1] and attack_time<=d[2] and not attack_connected
		if effective:
			var distance=point.distance_to(old_fists[hand])
			fist_speed=clampf(distance/maxf(delta,.001)/3.0,.65,1.25)
			# Sweep actual fist volume between sampled poses. No distance-only hit test.
			var samples=clampi(ceili(distance/.055),1,12)
			for step in range(samples+1):
				var query=PhysicsShapeQueryParameters3D.new()
				query.shape=fists[hand].get_child(0).shape
				query.transform=Transform3D(Basis.IDENTITY,old_fists[hand].lerp(point,float(step)/samples))
				query.collision_mask=8
				query.collide_with_areas=true
				query.collide_with_bodies=false
				for result in get_world_3d().direct_space_state.intersect_shape(query,8):
					var area=result.collider
					if area.has_meta("fighter") and area.get_meta("fighter")!=self:
						var victim=area.get_meta("fighter")
						var accuracy=clampf(1.0-point.distance_to(area.global_position),.6,1.0)
						if victim.receive_hit(self,current_punch,area.get_meta("zone"),fist_speed,accuracy,attack_id):
							attack_connected=true
							break
				if attack_connected: break
		old_fists[hand]=point

func receive_hit(attacker: Node,punch: String,zone: String,speed: float,accuracy: float,id: int) -> bool:
	if not fighting or state in [State.KNOCKDOWN,State.KO,State.GET_UP]: return false
	var key=str(attacker.get_instance_id())+":"+str(id)
	if hits_received.has(key): return false
	hits_received[key]=true
	if hits_received.size()>64: hits_received.erase(hits_received.keys()[0])
	var counter=state==State.ATTACKING or recovery>.03
	var blocked=state==State.BLOCKING and guard>0 and defense==("block_high" if zone=="head" else "block_body")
	var base: float=Punches.DATA[punch][3]
	var amount=Punches.damage(base,attacker.attack_stamina,speed,accuracy,counter,zone=="body",blocked)
	health=maxf(0,health-amount)
	if zone=="head": head_damage+=amount
	else:
		body_damage+=amount
		stamina=maxf(0,stamina-amount*1.1)
	if blocked:
		guard=maxf(0,guard-base*1.5)
		stamina=maxf(0,stamina-base*.35)
	else:
		stun+=amount*(1.45 if counter else 1.0)
		knockdown_meter+=amount*(1.0+head_damage/140.0)
		set_state(State.STUNNED if stun>32 else State.HURT,.20+base*.013,"stagger" if stun>32 else "hurt_"+zone)
		velocity += (global_position-attacker.global_position).normalized()*minf(1.5,amount*.09)
	attacker.landed+=1
	attacker.round_quality+=amount*(.4 if blocked else 1.0)
	var info={"damage":amount,"blocked":blocked,"counter":counter,"zone":zone,"punch":punch}
	attacker.hit_landed.emit(attacker,self,info)
	if health<=0 or knockdown_meter>42 or (stamina<3 and body_damage>65):
		knockdowns+=1
		round_knockdowns+=1
		set_state(State.KNOCKDOWN,0,"knockdown" if zone=="head" else "fall")
		knocked_down.emit(self)
	return true

func recover_from_down() -> void:
	health=maxf(health,22.0-knockdowns*3.0)
	stamina=maxf(stamina,38)
	knockdown_meter=0
	stun=0
	set_state(State.GET_UP,1.5,"get_up")

func debug_visible(enabled: bool) -> void:
	for mesh in debug_shapes: mesh.visible=enabled
