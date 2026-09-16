extends CharacterBody2D

@export var speed: float = 150.0
@export var attack_distance: float = 100.0
@export var attack_cooldown: float = 1.2
@export var max_health: int = 100

var health: int = 100
var player: Node2D
var can_attack: bool = true
var attacking: bool = false
var hurt: bool = false
var dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready():
	health = max_health
	player = get_tree().get_first_node_in_group("player")


func _physics_process(_delta):

	if dead:
		return

	if player == null:
		return

	if attacking or hurt:
		velocity.x = 0
		move_and_slide()
		return

	var distance_x = abs(
		player.global_position.x - global_position.x
	)

	# Mirar hacia Alonso
	if player.global_position.x < global_position.x:
		sprite.flip_h = true
	else:
		sprite.flip_h = false

	# Perseguir
	if distance_x > attack_distance:

		var direction = sign(
			player.global_position.x - global_position.x
		)

		velocity.x = direction * speed

		if sprite.animation != "run":
			sprite.play("run")

	else:

		velocity.x = 0

		if can_attack:
			attack()
		else:
			if sprite.animation != "idle":
				sprite.play("idle")

	move_and_slide()


func attack():

	if attacking:
		return

	attacking = true
	can_attack = false
	velocity.x = 0

	sprite.play("attack")

	await sprite.animation_finished

	attacking = false

	if not dead:
		sprite.play("idle")

	await get_tree().create_timer(attack_cooldown).timeout

	can_attack = true


func take_damage(damage: int):

	if dead:
		return

	health -= damage

	print("Vida enemigo: ", health)

	if health <= 0:
		die()
		return

	hurt = true
	attacking = false
	velocity.x = 0

	sprite.play("hurt")

	await sprite.animation_finished

	hurt = false

	if not dead:
		sprite.play("idle")


func die():

	dead = true
	velocity = Vector2.ZERO

	print("ENEMIGO KO")

	sprite.play("hurt")

	await sprite.animation_finished

	queue_free()
