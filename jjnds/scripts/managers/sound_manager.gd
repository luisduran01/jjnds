extends Node

# Sound Manager - plays sounds via AudioStreamPlayer nodes
# Sounds are generated procedurally using AudioStreamGenerator if no files present
# Just add .wav/.ogg files to res://audio/ with matching names to use them

const AUDIO_PATH = "res://audio/"
const MUSIC_PATH = "res://scripts/musica/"

const SOUNDS = {
	"punch_jab":     "punch_jab.wav",
	"punch_cross":   "punch_cross.wav",
	"punch_hook":    "punch_hook.wav",
	"punch_blocked": "punch_blocked.wav",
	"hurt":          "hurt.wav",
	"knockdown":     "knockdown.wav",
	"ko_bell":       "ko_bell.wav",
	"round_bell":    "round_bell.wav",
	"crowd_cheer":   "crowd_cheer.wav",
	"crowd_boo":     "crowd_boo.wav",
	"menu_select":   "menu_select.wav",
	"menu_back":     "menu_back.wav",
	"ambience_arena":"ambience_arena.wav",
	"ambience_gym":  "ambience_gym.wav"
}

const MUSIC = {
	"menu": "menu.mp3",
	"heavy": "Heavy_Weight.mp3",
	"career": "modocarrera.mp3",
	"select": "seleccionpersonajes.mp3"
}

var players: Dictionary = {}
var current_ambience: AudioStreamPlayer = null
var current_bgm: AudioStreamPlayer = null
var bgm_queue: String = ""
func _ready() -> void:
	for key in SOUNDS:
		var path = AUDIO_PATH + SOUNDS[key]
		if ResourceLoader.exists(path):
			var ap = AudioStreamPlayer.new()
			ap.stream = load(path)
			ap.name = key
			
			if "crowd" in key or "ambience" in key:
				ap.bus = "Crowd" if AudioServer.get_bus_index("Crowd") >= 0 else "Master"
			elif "menu" in key:
				ap.bus = "UI" if AudioServer.get_bus_index("UI") >= 0 else "Master"
			else:
				ap.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
				
			add_child(ap)
			players[key] = ap
			
	for key in MUSIC:
		var path = MUSIC_PATH + MUSIC[key]
		if ResourceLoader.exists(path):
			var ap = AudioStreamPlayer.new()
			ap.stream = load(path)
			ap.name = key
			ap.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
			ap.finished.connect(_on_bgm_finished.bind(key))
			add_child(ap)
			players[key] = ap

func play(sound_name: String, volume_db: float = 0.0, randomize_pitch: bool = false) -> void:
	if players.has(sound_name):
		var p = players[sound_name]
		p.volume_db = volume_db
		if randomize_pitch:
			p.pitch_scale = randf_range(0.85, 1.15)
		else:
			p.pitch_scale = 1.0
		p.play()

func stop(sound_name: String) -> void:
	if players.has(sound_name):
		players[sound_name].stop()

func play_ambience(ambience_name: String, fade_time: float = 1.0) -> void:
	if current_ambience and current_ambience.name == ambience_name and current_ambience.playing:
		return
		
	if current_ambience:
		var tw = create_tween()
		tw.tween_property(current_ambience, "volume_db", -40.0, fade_time)
		tw.tween_callback(current_ambience.stop)
		
	if players.has(ambience_name):
		current_ambience = players[ambience_name]
		current_ambience.volume_db = -40.0
		current_ambience.play()
		var tw2 = create_tween()
		tw2.tween_property(current_ambience, "volume_db", -10.0, fade_time)

func stop_ambience(fade_time: float = 1.0) -> void:
	if current_ambience:
		var tw = create_tween()
		tw.tween_property(current_ambience, "volume_db", -40.0, fade_time)
		tw.tween_callback(current_ambience.stop)
		current_ambience = null

func play_bgm(music_name: String, queue_next: String = "", fade_time: float = 1.0) -> void:
	if current_bgm and current_bgm.name == music_name and current_bgm.playing:
		bgm_queue = queue_next
		return
		
	if current_bgm:
		var tw = create_tween()
		tw.tween_property(current_bgm, "volume_db", -40.0, fade_time)
		tw.tween_callback(current_bgm.stop)
		
	if players.has(music_name):
		current_bgm = players[music_name]
		bgm_queue = queue_next
		current_bgm.volume_db = -40.0
		current_bgm.play()
		var tw2 = create_tween()
		tw2.tween_property(current_bgm, "volume_db", -10.0, fade_time)

func stop_bgm(fade_time: float = 1.0) -> void:
	if current_bgm:
		var tw = create_tween()
		tw.tween_property(current_bgm, "volume_db", -40.0, fade_time)
		tw.tween_callback(current_bgm.stop)
		current_bgm = null
		bgm_queue = ""

func _on_bgm_finished(music_name: String) -> void:
	if current_bgm and current_bgm.name == music_name and bgm_queue != "":
		play_bgm(bgm_queue)
