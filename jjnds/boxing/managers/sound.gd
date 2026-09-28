extends Node

# Original synthesized placeholders. Replace entries in clips with licensed AudioStreams.
var clips: Dictionary={}
var voices: Array[AudioStreamPlayer]=[]
var index=0

func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream=null
	voices.clear()
	clips.clear()

func _ready() -> void:
	if DisplayServer.get_name()=="headless": return
	for name in ["jab","cross","hook","uppercut","body","blocked","knockdown","bell","ko","menu","crowd"]:
		clips[name]=synthesize(name)
	for i in 10:
		var voice=AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	var ambience=AudioStreamPlayer.new()
	ambience.stream=clips.crowd
	ambience.volume_db=-25
	add_child(ambience)
	ambience.play()

func play(kind: String,intensity: float=1.0) -> void:
	if voices.is_empty(): return
	var voice=voices[index%voices.size()]
	index+=1
	voice.stream=clips.get(kind,clips.jab)
	voice.volume_db=linear_to_db(clampf(intensity,.12,1.2)) - 9
	voice.pitch_scale=randf_range(.94,1.06)
	voice.play()

func synthesize(kind: String) -> AudioStreamWAV:
	var rate=22050
	var duration=1.8 if kind in ["bell","ko"] else 2.0 if kind=="crowd" else .19
	var count=int(rate*duration)
	var bytes=PackedByteArray()
	bytes.resize(count*2)
	var smooth=0.0
	var rng=RandomNumberGenerator.new()
	rng.seed=hash(kind)
	for i in count:
		var t=float(i)/rate
		var noise=rng.randf_range(-1,1)
		smooth=lerpf(smooth,noise,.075)
		var sample=0.0
		if kind=="bell": sample=(sin(t*TAU*740)+sin(t*TAU*1140)*.45+sin(t*TAU*1740)*.2)*exp(-t*3)*.45
		elif kind=="crowd": sample=smooth*.55
		else:
			var frequency=80.0 if kind in ["body","knockdown","hook"] else 140.0
			sample=(sin(TAU*frequency*t)*.6+noise*.4)*exp(-t*28)*minf(t*500,1)
		bytes.encode_s16(i*2,int(clampf(sample,-1,1)*26000))
	var stream=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=bytes
	if kind=="crowd":
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
		stream.loop_end=count
	return stream
