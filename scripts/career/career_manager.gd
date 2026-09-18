extends Node
class_name CareerManager

const SAVE_PATH = "user://career_save.tres"

const ROSTER_PATH = "res://resources/boxers/"

var career: CareerData = null
var full_ranking: Array = [] # Array of BoxerData

signal career_loaded(career: CareerData)

func _ready() -> void:
	load_full_roster()

func load_full_roster() -> void:
	full_ranking.clear()
	var dir = DirAccess.open(ROSTER_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				full_ranking.append(load(ROSTER_PATH + file_name))
			file_name = dir.get_next()
	# Sort by overall descending
	full_ranking.sort_custom(func(a, b): return a.overall > b.overall)

func create_new_career(boxer_profile: Resource) -> void:
	career = CareerData.new()
	career.boxer_name = boxer_profile.boxer_name
	career.boxer_data_path = "res://resources/boxers/" + boxer_profile.boxer_name.to_lower().replace(" ", "_") + ".tres"
	career.rank = full_ranking.size()
	career.money = 1000
	save_career()
	career_loaded.emit(career)

func save_career() -> void:
	if career:
		career.save(SAVE_PATH)

func load_career() -> bool:
	var loaded = CareerData.load_career(SAVE_PATH)
	if loaded:
		career = loaded
		career_loaded.emit(career)
		return true
	return false

func has_save() -> bool:
	return ResourceLoader.exists(SAVE_PATH)

func get_next_opponent() -> Resource:
	if full_ranking.is_empty():
		return null
	# Return the boxer ranked just above the player
	var target_rank = max(0, career.rank - 2)
	if target_rank < full_ranking.size():
		return full_ranking[target_rank]
	return full_ranking[0]

func get_ranking_display() -> Array:
	var display = []
	for i in full_ranking.size():
		display.append({
			"rank": i + 1,
			"name": full_ranking[i].boxer_name,
			"overall": full_ranking[i].overall
		})
	return display

func on_fight_result(player_won: bool, was_ko: bool) -> void:
	if not career:
		return
	career.reset_temp_boosts()
	if player_won:
		career.record_win(was_ko)
	else:
		career.record_loss()
	save_career()
