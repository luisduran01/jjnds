extends Node3D

var crowd: MultiMeshInstance3D
var excitement = 0.0
var crowd_clock = 0.0
var referee: Node3D
var fight
var crowd_base: Array[Transform3D] = []

func material(color: Color,metal: float=0.0) -> StandardMaterial3D:
	var mat=StandardMaterial3D.new()
	mat.albedo_color=color
	mat.roughness=.76
	mat.metallic=metal
	return mat

func box(label: String,size: Vector3,where: Vector3,color: Color,solid: bool=false,parent: Node=null) -> MeshInstance3D:
	if parent==null: parent=self
	var mesh=MeshInstance3D.new()
	mesh.name=label
	var shape=BoxMesh.new()
	shape.size=size
	mesh.mesh=shape
	mesh.material_override=material(color)
	mesh.position=where
	parent.add_child(mesh)
	if solid:
		var body=StaticBody3D.new()
		var collision=CollisionShape3D.new()
		var bounds=BoxShape3D.new()
		bounds.size=size
		collision.shape=bounds
		body.add_child(collision)
		mesh.add_child(body)
	return mesh

func cylinder(label: String,from: Vector3,to: Vector3,radius: float,color: Color,parent: Node=null) -> MeshInstance3D:
	if parent==null: parent=self
	var mesh=MeshInstance3D.new()
	mesh.name=label
	var shape=CylinderMesh.new()
	shape.top_radius=radius
	shape.bottom_radius=radius
	shape.height=from.distance_to(to)
	shape.radial_segments=12
	mesh.mesh=shape
	mesh.material_override=material(color)
	mesh.position=(from+to)*.5
	mesh.quaternion=Quaternion(Vector3.UP,(to-from).normalized())
	parent.add_child(mesh)
	return mesh

func _ready() -> void:
	box("Canvas",Vector3(7,.22,7),Vector3(0,-.11,0),Color("233e4b"),true)
	box("Apron",Vector3(7.35,.6,7.35),Vector3(0,-.48,0),Color("111b27"))
	box("HallFloor",Vector3(28,.2,26),Vector3(0,-.9,0),Color("151c25"),true)
	for s in [-1,1]:
		for x in [-1,1]:
			var color=Color("d34c40") if s==x else Color("e5ded0")
			cylinder("Post",Vector3(s*3.35,-.7,x*3.35),Vector3(s*3.35,1.65,x*3.35),.07,Color("abb4bd"))
			box("CornerPad",Vector3(.22,.95,.22),Vector3(s*3.23,1.02,x*3.23),color)
		for level in 4:
			var y=.47+level*.32
			var color=[Color("d2d7d7"),Color("2f6287"),Color("d2d7d7"),Color("c93d35")][level]
			cylinder("RopeX",Vector3(-3.25,y,s*3.25),Vector3(3.25,y,s*3.25),.027,color)
			cylinder("RopeZ",Vector3(s*3.25,y,-3.25),Vector3(s*3.25,y,3.25),.027,color)
		var wall=box("PhysicalRopeBoundaryX",Vector3(.12,2.4,6.6),Vector3(s*3.25,1,0),Color.WHITE,true)
		wall.visible=false
		wall=box("PhysicalRopeBoundaryZ",Vector3(6.6,2.4,.12),Vector3(0,1,s*3.25),Color.WHITE,true)
		wall.visible=false
		box("Wall",Vector3(28,8,.3),Vector3(0,3,s*11),Color("283240"))
	for x in range(-12,13,4):
		box("Column",Vector3(.25,8,.4),Vector3(x,3,-10.7),Color("111924"))
		box("Window",Vector3(2.8,1.6,.1),Vector3(x,3.9,-10.48),Color("566877"))
	var logo=Label3D.new()
	logo.text="CORNER\nCLUB"
	logo.font_size=140
	logo.pixel_size=.008
	logo.modulate=Color(.62,.67,.61,.5)
	logo.rotation_degrees.x=-90
	logo.position=Vector3(0,.015,0)
	logo.no_depth_test=false
	add_child(logo)
	var env=WorldEnvironment.new()
	var settings=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("101722")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("b6c7d7")
	settings.ambient_light_energy=.4
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=settings
	add_child(env)
	var key=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-58,-25,0)
	key.light_color=Color("fff0db")
	key.light_energy=1.1
	key.shadow_enabled=true
	key.directional_shadow_max_distance=25
	add_child(key)
	var fill=OmniLight3D.new()
	fill.position=Vector3(1,5,2)
	fill.omni_range=12
	fill.light_energy=.8
	add_child(fill)
	build_crowd()
	build_referee()

func build_crowd() -> void:
	crowd=MultiMeshInstance3D.new()
	crowd.name="InstancedCrowd"
	var multi=MultiMesh.new()
	multi.transform_format=MultiMesh.TRANSFORM_3D
	multi.use_colors=true
	var mat=material(Color.WHITE)
	mat.vertex_color_use_as_albedo=true
	var surface=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torso=BoxMesh.new()
	torso.size=Vector3(.34,.5,.22)
	surface.append_from(torso,0,Transform3D(Basis.IDENTITY,Vector3.ZERO))
	var head=SphereMesh.new()
	head.radius=.12
	head.height=.25
	head.radial_segments=8
	head.rings=4
	surface.append_from(head,0,Transform3D(Basis.IDENTITY,Vector3(0,.4,0)))
	var limb=BoxMesh.new()
	limb.size=Vector3(.11,.42,.13)
	for side in [-1,1]:
		surface.append_from(limb,0,Transform3D(Basis.IDENTITY,Vector3(side*.11,-.44,0)))
		surface.append_from(limb,0,Transform3D(Basis.IDENTITY,Vector3(side*.23,-.05,0)))
	var crowd_mesh=surface.commit()
	crowd_mesh.surface_set_material(0,mat)
	multi.mesh=crowd_mesh
	multi.instance_count=144
	crowd.multimesh=multi
	crowd.visibility_range_end=35
	add_child(crowd)
	var rng=RandomNumberGenerator.new()
	rng.seed=441
	for i in 144:
		var row=i/36
		var col=i%36
		var side=1 if col>=18 else -1
		var p=Vector3((col%18-8.5)*.57,.15+row*.5,side*(5.0+row*.7))
		var trans=Transform3D(Basis.IDENTITY,p)
		crowd_base.append(trans)
		multi.set_instance_transform(i,trans)
		multi.set_instance_color(i,Color.from_hsv(rng.randf(),.35,rng.randf_range(.09,.3)))
		if col==0 or col==18:
			box("Bleacher",Vector3(11,.35,1),Vector3(0,p.y-.6,p.z),Color("242b32"))

func build_referee() -> void:
	referee=Node3D.new()
	referee.name="Referee"
	add_child(referee)
	referee.position=Vector3(1.8,0,-1.7)
	box("Shirt",Vector3(.37,.53,.23),Vector3(0,1.23,0),Color("cfdae0"),false,referee)
	var head=MeshInstance3D.new()
	var sphere=SphereMesh.new()
	sphere.radius=.13
	sphere.height=.28
	head.mesh=sphere
	head.material_override=material(Color("ad7b58"))
	head.position.y=1.67
	referee.add_child(head)
	for side in [-1,1]:
		cylinder("Leg",Vector3(side*.11,.97,0),Vector3(side*.12,.10,0),.085,Color("161d29"),referee)
		cylinder("Arm",Vector3(side*.23,1.44,0),Vector3(side*.28,.99,.06),.06,Color("cfdae0"),referee)
	box("Bowtie",Vector3(.15,.06,.025),Vector3(0,1.47,.13),Color("152032"),false,referee)

func _process(delta: float) -> void:
	excitement=move_toward(excitement,0,delta*.3)
	crowd_clock+=delta
	if excitement>.05:
		for i in crowd_base.size():
			var trans=crowd_base[i]
			trans.origin.y+=absf(sin(crowd_clock*7+i*.7))*.12*excitement
			crowd.multimesh.set_instance_transform(i,trans)
	if fight and fight.player:
		var middle=(fight.player.position+fight.enemy.position)*.5
		var desired=middle+Vector3(1.65,0,-1.5)
		if fight.down_fighter: desired=fight.down_fighter.position+Vector3(.65,0,-.75)
		desired.x=clampf(desired.x,-2.65,2.65)
		desired.z=clampf(desired.z,-2.65,2.65)
		referee.position=referee.position.move_toward(desired,delta*1.2)
		if referee.position.distance_to(middle)>.1: referee.look_at(Vector3(middle.x,0,middle.z),Vector3.UP,true)
