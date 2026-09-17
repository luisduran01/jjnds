extends Node2D


@onready var player = $Player
@onready var enemy = $Enemy

@onready var player_health_bar: ProgressBar = $HUD/PlayerHealthBar
@onready var enemy_health_bar: ProgressBar = $HUD/EnemyHealthBar


func _ready() -> void:
	player_health_bar.max_value = player.max_health
	player_health_bar.value = player.health

	enemy_health_bar.max_value = enemy.max_health
	enemy_health_bar.value = enemy.health

	player.health_changed.connect(_on_player_health_changed)
	enemy.health_changed.connect(_on_enemy_health_changed)

	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)


func _on_player_health_changed(health: int) -> void:
	player_health_bar.value = health


func _on_enemy_health_changed(health: int) -> void:
	enemy_health_bar.value = health


func _on_player_died() -> void:
	print("GAME OVER")


func _on_enemy_died() -> void:
	print("ENEMIGO DERROTADO")
