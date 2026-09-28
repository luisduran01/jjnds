extends Node

var player_profile: Resource # BoxerData
var enemy_profile: Resource # BoxerData
var fight_rounds: int = 3
var is_career_mode: bool = false
var current_career: Resource = null # CareerData
var fight_mode := "quick"
var fight_ai_style := "Pressure Fighter"

func configure_fight(mode: String, player: Resource, enemy: Resource, rounds: int=3, ai_style: String="Pressure Fighter") -> void:
	fight_mode=mode
	player_profile=player
	enemy_profile=enemy
	fight_rounds=rounds
	fight_ai_style=ai_style
	is_career_mode=mode=="career"

func clear_fight_context() -> void:
	fight_mode="quick"
	player_profile=null
	enemy_profile=null
	fight_rounds=3
	fight_ai_style="Pressure Fighter"
