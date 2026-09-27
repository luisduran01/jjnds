extends RefCounted
class_name DamageAccumulator

const SIZE := 256
var image: Image
var texture: ImageTexture
var regions := {}

func _init() -> void:
	image=Image.create_empty(SIZE,SIZE,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	texture=ImageTexture.create_from_image(image)
	for region in ["head_left","head_right","head_center","body_left","body_right"]:
		regions[region]=0.0

func stamp(region: String, uv: Vector2, severity: float, radius: float=.08, cut: float=.0) -> void:
	if not regions.has(region): regions[region]=0.0
	regions[region]=minf(1.0,float(regions[region])+severity*.12)
	var center=Vector2i(clampi(int(uv.x*SIZE),0,SIZE-1),clampi(int(uv.y*SIZE),0,SIZE-1))
	var pixels=maxi(2,int(radius*SIZE))
	for y in range(maxi(0,center.y-pixels),mini(SIZE,center.y+pixels+1)):
		for x in range(maxi(0,center.x-pixels),mini(SIZE,center.x+pixels+1)):
			var falloff=1.0-Vector2(x-center.x,y-center.y).length()/float(pixels)
			if falloff<=0: continue
			var old=image.get_pixel(x,y)
			image.set_pixel(x,y,Color(minf(1.0,old.r+severity*falloff*.18),minf(1.0,old.g+cut*falloff*.22),minf(1.0,old.b+severity*falloff*.08),1.0))
	texture.update(image)

func region_damage(region: String) -> float:
	return float(regions.get(region,0.0))
