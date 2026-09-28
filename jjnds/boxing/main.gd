extends Node3D

const Fighter=preload("res://boxing/characters/fighter.gd")
const Brain=preload("res://boxing/ai/boxing_brain.gd")
const Arena=preload("res://boxing/arena/ring.gd")
const Director=preload("res://boxing/managers/fight_director.gd")
const Camera=preload("res://boxing/arena/fight_camera.gd")
const Sound=preload("res://boxing/managers/sound.gd")
const HUD=preload("res://boxing/ui/hud.gd")
const Studio=preload("res://boxing/arena/studio_environment.gd")
var fight
var brain
var hud

func _ready() -> void:
	Studio.add_to(self)
	preload("res://boxing/managers/input_setup.gd").install()
	fight=Director.new()
	fight.name="FightManager"
	var arena=Arena.new()
	arena.name="Ring"
	add_child(arena)
	var sound=Sound.new()
	sound.name="SoundManager"
	add_child(sound)
	var player=Fighter.new()
	player.name="Player"
	player.is_player=true
	var gm=get_node_or_null("/root/GameManager")
	player.boxer_data=gm.player_profile if gm and gm.player_profile else load("res://resources/boxers/alonso.tres")
	player.position=Vector3(-1.05,0,0)
	add_child(player)
	var enemy=Fighter.new()
	enemy.name="Opponent"
	enemy.boxer_name="VEGA"
	enemy.boxer_data=gm.enemy_profile if gm and gm.enemy_profile else load("res://resources/boxers/alex_volkov.tres")
	enemy.position=Vector3(1.05,0,0)
	enemy.team_color=Color("62acd8")
	add_child(enemy)
	player.opponent=enemy
	enemy.opponent=player
	brain=Brain.new()
	brain.name="BoxingAI"
	brain.fighter=enemy
	if gm: brain.style=gm.fight_ai_style
	add_child(brain)
	var camera=Camera.new()
	camera.name="FightCamera"
	camera.fight=fight
	add_child(camera)
	fight.player=player
	fight.enemy=enemy
	fight.arena=arena
	fight.sound=sound
	fight.camera=camera
	if gm: fight.rounds_choice=str(gm.fight_rounds)
	arena.fight=fight
	add_child(fight)
	for boxer in [player,enemy]:
		boxer.knocked_down.connect(fight.on_knockdown)
		boxer.hit_landed.connect(fight.on_hit)
		# Registrar lanzamientos para estadísticas
		boxer.hit_landed.connect(func(atk,vic,info): fight.on_throw(atk))
		# Riesgo de parada médica
		boxer.medical_risk.connect(fight.on_medical_risk)
	hud=HUD.new()
	hud.name="BroadcastHUD"
	hud.fight=fight
	hud.brain=brain
	add_child(hud)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("box_debug"):
		hud.debug=!hud.debug
		fight.player.debug_visible(hud.debug)
		fight.enemy.debug_visible(hud.debug)
	if event.is_action_pressed("box_restart") and fight.phase==fight.Phase.FIGHT_END:
		get_tree().reload_current_scene()
