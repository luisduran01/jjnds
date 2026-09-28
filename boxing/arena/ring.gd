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
	# Professional event ring: the combat root remains unchanged; all visual work
	# lives under Arena/Ring so Fighter, hitboxes and the camera keep their paths.
	box("Canvas",Vector3(7,.22,7),Vector3(0,-.11,0),Color("aeb4ae"),true)
	box("CanvasInset",Vector3(6.45,.035,6.45),Vector3(0,.018,0),Color("c4c8bf"))
	box("Apron",Vector3(7.45,.6,7.45),Vector3(0,-.48,0),Color("111827"))
	box("Understructure",Vector3(8.1,.32,8.1),Vector3(0,-.85,0),Color("070b12"))
	box("HallFloor",Vector3(34,.2,30),Vector3(0,-1.03,0),Color("080c14"),true)
	# Steel steps and ringside barricades make the platform read as an event space.
	for step in 3:
		box("RingStep%d"%step,Vector3(1.45,.18,.48+step*.16),Vector3(0,-.82-step*.16,4.0+step*.18),Color("59616b"),true)
	for side in [-1,1]:
		box("Barricade%d"%side,Vector3(12,.9,.11),Vector3(0,-.48,side*6.0),Color("273241"))
		for x in range(-5,6,2): cylinder("BarrierPost",Vector3(x,-.95,side*6.0),Vector3(x,-.05,side*6.0),.035,Color("8f9baa"))
	for s in [-1,1]:
		for x in [-1,1]:
			var color=Color("d73940") if s==x else Color("2378d0")
			cylinder("Post",Vector3(s*3.35,-.7,x*3.35),Vector3(s*3.35,1.65,x*3.35),.07,Color("abb4bd"))
			box("CornerPad",Vector3(.30,1.05,.30),Vector3(s*3.23,1.02,x*3.23),color)
			box("CornerTopPad",Vector3(.42,.19,.42),Vector3(s*3.23,1.60,x*3.23),color)
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
	logo.text="BOXIN SSJJ"
	logo.font_size=160
	logo.pixel_size=.008
	logo.outline_size=8
	logo.modulate=Color("182842")
	logo.rotation_degrees.x=-90
	logo.position=Vector3(0,.015,0)
	logo.no_depth_test=false
	add_child(logo)
	for z in [-2.65,2.65]:
		var edge_brand=Label3D.new()
		edge_brand.text="SSJJ  •  LIVE BOXING"
		edge_brand.font_size=48
		edge_brand.pixel_size=.008
		edge_brand.modulate=Color("45536b")
		edge_brand.rotation_degrees.x=-90
		edge_brand.position=Vector3(0,.018,z)
		add_child(edge_brand)
	var env=WorldEnvironment.new()
	var settings=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("03050a")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color("b6c7d7")
	settings.ambient_light_energy=.28
	settings.glow_enabled=true
	settings.glow_intensity=1.15
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	env.environment=settings
	add_child(env)
	var key=DirectionalLight3D.new()
	key.rotation_degrees=Vector3(-58,-25,0)
	key.light_color=Color("fff0db")
	key.light_energy=.45
	key.shadow_enabled=true
	key.directional_shadow_max_distance=25
	add_child(key)
	var fill=OmniLight3D.new()
	fill.position=Vector3(1,5,2)
	fill.omni_range=12
	fill.light_energy=.8
	add_child(fill)
	build_light_truss()
	build_ringside()
	build_crowd()
	build_referee()

func build_light_truss() -> void:
	var truss_color=Color("48515c")
	for x in [-4.2,4.2]:
		cylinder("TrussRail",Vector3(x,5.8,-4.2),Vector3(x,5.8,4.2),.06,truss_color)
	for z in [-4.2,4.2]:
		cylinder("TrussRail",Vector3(-4.2,5.8,z),Vector3(4.2,5.8,z),.06,truss_color)
	for x in [-2.5,0.0,2.5]:
		for z in [-2.5,2.5]:
			var spot=SpotLight3D.new()
			spot.position=Vector3(x,5.65,z)
			spot.rotation_degrees=Vector3(-90,0,0)
			spot.light_color=Color("fff1d8")
			spot.light_energy=2.3
			spot.spot_range=10.0
			spot.spot_angle=36.0
			spot.shadow_enabled=true
			add_child(spot)

func build_ringside() -> void:
	for side in [-1,1]:
		for x in [-2.4,0.0,2.4]:
			var table=box("RingsideTable",Vector3(1.15,.52,.48),Vector3(x,-.72,side*4.45),Color("172130"))
			# Local coordinates: this is a child of the table, not the arena root.
			box("TableScreen",Vector3(.48,.28,.03),Vector3(0,.38,-side*.30),Color("5aa8d9"),false,table)
			# Low-poly staff: near enough to read, cheap enough to keep the focus on fighters.
			var staff=Node3D.new()
			staff.position=Vector3(x+(0.33 if side<0 else -.33),-.88,side*4.9)
			add_child(staff)
			box("StaffBody",Vector3(.28,.52,.18),Vector3.ZERO+Vector3(0,.72,0),Color("303a49"),false,staff)
			var head=SphereMesh.new()
			head.radius=.13; head.height=.26
			var head_mesh=MeshInstance3D.new()
			head_mesh.mesh=head; head_mesh.material_override=material(Color("a97858")); head_mesh.position=Vector3(0,1.12,0)
			staff.add_child(head_mesh)

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
	var crowd_count = 64 if (OS.has_feature("web") or OS.has_feature("mobile")) else 120
	multi.instance_count=crowd_count
	crowd.multimesh=multi
	crowd.visibility_range_end=28
	add_child(crowd)
	var rng=RandomNumberGenerator.new()
	rng.seed=441
	for i in crowd_count:
		var row=i/30
		var col=i%30
		var side=1 if col>=15 else -1
		var p=Vector3((col%15-7.0)*.65,.15+row*.5,side*(5.0+row*.7))
		var trans=Transform3D(Basis.IDENTITY,p)
		crowd_base.append(trans)
		multi.set_instance_transform(i,trans)
		multi.set_instance_color(i,Color.from_hsv(rng.randf(),.35,rng.randf_range(.09,.3)))
		if col==0 or col==15:
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
	if excitement>.08 and crowd:
		for i in range(0, crowd_base.size(), 2):
			var trans=crowd_base[i]
			trans.origin.y+=absf(sin(crowd_clock*7+i*.7))*.12*excitement
			crowd.multimesh.set_instance_transform(i,trans)
	if fight and fight.player:
		var middle=(fight.player.position+fight.enemy.position)*.5
		# Keep the referee at ringside so the broadcast camera never frames him
		# between the fighters; combat logic does not depend on his position.
		var desired=Vector3(2.85,0,-2.85)
		referee.position=referee.position.move_toward(desired,delta*1.2)
		if referee.position.distance_to(middle)>.1: referee.look_at(Vector3(middle.x,0,middle.z),Vector3.UP,true)
