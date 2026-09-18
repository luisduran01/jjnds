extends Resource
class_name BoxerData

# Biographical
@export var portrait: Texture2D
@export var boxer_name: String = "Unknown"
@export var nickname: String = ""
@export var country: String = "Unknown"
@export var age: int = 20
@export var height: float = 180.0 # cm
@export var reach: float = 182.0 # cm
@export var weight: float = 147.0 # lbs (Welterweight)

# Base Stats (0-100)
@export var overall: int = 60
@export var health: int = 100
@export var stamina_max: float = 100.0
@export var power: int = 60
@export var speed: int = 60
@export var defense: int = 60
@export var chin: int = 60
@export var body_resistance: int = 60
@export var accuracy: int = 60
@export var movement: int = 60
@export var recovery: int = 60

# Specific Power Stats (Base damage values)
@export var jab_power: int = 10
@export var cross_power: int = 20
@export var hook_power: int = 25
@export var uppercut_power: int = 30
@export var body_shot_power: int = 15

# Specific Costs (Stamina cost)
@export var jab_cost: float = 8.0
@export var cross_cost: float = 15.0
@export var hook_cost: float = 20.0
@export var uppercut_cost: float = 25.0
@export var body_shot_cost: float = 12.0

# Timings (derived usually, but can be hardcoded here for simplicity)
@export var jab_cooldown: float = 0.25
@export var cross_cooldown: float = 0.45
@export var hook_cooldown: float = 0.5
@export var uppercut_cooldown: float = 0.6
@export var body_shot_cooldown: float = 0.4
@export var stamina_regen_rate: float = 20.0

# AI Style
# enum from enemy.gd
@export var ai_style: int = 4 # BALANCED
