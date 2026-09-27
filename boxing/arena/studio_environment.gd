extends RefCounted

static func add_to(parent: Node3D) -> void:
	var world=WorldEnvironment.new()
	var env=Environment.new()
	env.background_mode=Environment.BG_COLOR
	env.background_color=Color("10131a")
	env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color=Color("9db7d5")
	env.ambient_light_energy=.38
	env.tonemap_mode=Environment.TONE_MAPPER_AGX
	var is_low_end := OS.has_feature("mobile") or OS.has_feature("web")
	if not is_low_end:
		env.ssao_enabled=true
		env.ssao_radius=1.4
	else:
		env.ssao_enabled=false
	env.glow_enabled=true
	world.environment=env
	parent.add_child(world)
	for x in [-3.0,0.0,3.0]:
		var spot=SpotLight3D.new()
		spot.position=Vector3(x,5,1)
		spot.rotation_degrees=Vector3(-62,0,0)
		spot.light_energy=4.0
		spot.spot_range=12.0
		spot.spot_angle=42.0
		parent.add_child(spot)
