extends "res://boxing/main.gd"

var elapsed=0.0
var phase_visits: Dictionary={}
var extra_brain
var completed=false
var frame_count=0
var fps_sum=0.0

func _ready() -> void:
	super._ready()
	hud.menu.hide()
	fight.round_time=15
	fight.rest_time=3
	fight.rounds_choice="3"
	fight.player.is_player=false
	extra_brain=Brain.new()
	extra_brain.fighter=fight.player
	extra_brain.style="Swarmer"
	add_child(extra_brain)
	fight.begin()

func _process(delta: float) -> void:
	if completed: return
	elapsed+=delta
	frame_count+=1
	fps_sum+=Engine.get_frames_per_second()
	phase_visits[fight.Phase.keys()[fight.phase]]=true
	if fight.phase==fight.Phase.FIGHT_END or elapsed>90:
		completed=true
		var report={"result":fight.result,"elapsed_seconds":elapsed,"round":fight.round_number,"player_hits":fight.player.landed,"enemy_hits":fight.enemy.landed,"player_throws":fight.player.thrown,"enemy_throws":fight.enemy.thrown,"phases":phase_visits.keys(),"average_fps":fps_sum/maxi(1,frame_count),"complete":fight.phase==fight.Phase.FIGHT_END}
		FileAccess.open("res://boxing/tests/endurance.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://boxing/tests/result.png")
		print("ENDURANCE: ",report)
		get_tree().quit(0 if report.complete and report.player_hits+report.enemy_hits>0 else 1)
