extends Resource
class_name CareerData

@export var boxer_data_path: String = ""
@export var boxer_name: String = "Unknown"
@export var wins: int = 0
@export var losses: int = 0
@export var draws: int = 0
@export var kos: int = 0
@export var rank: int = 50
@export var money: int = 1000
@export var fans: int = 0
@export var current_round: int = 1

# Temporary attribute boosts from training (reset per fight)
@export var temp_power_boost: int = 0
@export var temp_speed_boost: int = 0
@export var temp_stamina_boost: float = 0.0
@export var temp_defense_boost: int = 0

func record_win(was_ko: bool) -> void:
	wins += 1
	if was_ko:
		kos += 1
	fans += 500
	money += 2500
	if rank > 1:
		rank -= 1

func record_loss() -> void:
	losses += 1
	fans = max(0, fans - 100)
	money += 500
	rank = min(50, rank + 3)

func record_draw() -> void:
	draws += 1
	fans += 100
	money += 800

func reset_temp_boosts() -> void:
	temp_power_boost = 0
	temp_speed_boost = 0
	temp_stamina_boost = 0.0
	temp_defense_boost = 0

func save(save_path: String) -> void:
	ResourceSaver.save(self, save_path)

static func load_career(load_path: String) -> CareerData:
	if ResourceLoader.exists(load_path):
		return ResourceLoader.load(load_path) as CareerData
	return null
