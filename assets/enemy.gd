extends CharacterBody2D

# ============================================================
# CONFIGURACIÓN
# ============================================================

@export var speed: float = 120.0

@export var attack_distance: float = 90.0
@export var attack_cooldown: float = 1.0

@export var max_health: int = 100
@export var damage: int = 15

@export var hitbox_delay: float = 0.15
@export var hitbox_active_time: float = 0.12

@export var knockback_force: float = 60.0


# ============================================================
# VARIABLES
# ============================================================

var health: int = 100

var player: Node2D = null

var attacking: bool = false
var can_attack: bool = true

var is_hurt: bool = false
var dead: bool = false

# Evita que un ataque del enemigo golpee
# varias veces al jugador.
var player_hit_this_attack: bool = false


# ============================================================
# NODOS
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox


# ============================================================
# READY
# ============================================================

func _ready() -> void:

	health = max_health

	attack_hitbox.monitoring = false

	player = get_tree().get_first_node_in_group("player")


	if sprite.sprite_frames.has_animation("idle"):

		sprite.play("idle")


# ============================================================
# PHYSICS PROCESS
# ============================================================

func _physics_process(_delta: float) -> void:

	if dead:
		return


	# --------------------------------------------------------
	# BUSCAR AL PLAYER SI TODAVÍA NO EXISTE
	# --------------------------------------------------------

	if player == null:

		player = get_tree().get_first_node_in_group("player")

		return


	# --------------------------------------------------------
	# SI ALONSO ESTÁ KO
	# --------------------------------------------------------

	if "dead" in player:

		if player.dead:

			velocity.x = 0.0

			if not attacking and not is_hurt:

				sprite.play("idle")

			move_and_slide()

			return


	# --------------------------------------------------------
	# HURT / ATAQUE
	# --------------------------------------------------------

	if is_hurt or attacking:

		velocity.x = 0.0

		move_and_slide()

		return


	# --------------------------------------------------------
	# DISTANCIA
	# --------------------------------------------------------

	var distance_x: float = abs(
		player.global_position.x - global_position.x
	)


	# --------------------------------------------------------
	# MIRAR HACIA ALONSO
	# --------------------------------------------------------

	if player.global_position.x < global_position.x:

		sprite.flip_h = true

		update_hitbox_direction(true)


	else:

		sprite.flip_h = false

		update_hitbox_direction(false)


	# --------------------------------------------------------
	# PERSEGUIR
	# --------------------------------------------------------

	if distance_x > attack_distance:

		var direction: float = sign(
			player.global_position.x - global_position.x
		)

		velocity.x = direction * speed


		if sprite.animation != "run":

			sprite.play("run")


	# --------------------------------------------------------
	# ATACAR
	# --------------------------------------------------------

	else:

		velocity.x = 0.0


		if can_attack:

			attack()


		else:

			if sprite.animation != "idle":

				sprite.play("idle")


	move_and_slide()


# ============================================================
# ATAQUE
# ============================================================

func attack() -> void:

	if dead:
		return

	if is_hurt:
		return

	if attacking:
		return

	if not can_attack:
		return


	attacking = true
	can_attack = false

	player_hit_this_attack = false

	velocity.x = 0.0


	sprite.play("attack")


	# --------------------------------------------------------
	# ESPERAR HASTA QUE SALGA EL PUÑO
	# --------------------------------------------------------

	await get_tree().create_timer(
		hitbox_delay
	).timeout


	if dead or is_hurt:

		attack_hitbox.monitoring = false

		attacking = false

		can_attack = true

		return


	# --------------------------------------------------------
	# ACTIVAR HITBOX
	# --------------------------------------------------------

	attack_hitbox.monitoring = true


	await get_tree().create_timer(
		hitbox_active_time
	).timeout


	# --------------------------------------------------------
	# DESACTIVAR HITBOX
	# --------------------------------------------------------

	attack_hitbox.monitoring = false


	# --------------------------------------------------------
	# TERMINAR ANIMACIÓN
	# --------------------------------------------------------

	if sprite.animation == "attack":

		await sprite.animation_finished


	attacking = false


	if not dead and not is_hurt:

		sprite.play("idle")


	# --------------------------------------------------------
	# COOLDOWN
	# --------------------------------------------------------

	await get_tree().create_timer(
		attack_cooldown
	).timeout


	if not dead:

		can_attack = true


# ============================================================
# HITBOX DEL ENEMIGO TOCA A ALONSO
# ============================================================

func _on_attack_hitbox_area_entered(area: Area2D) -> void:

	if dead:
		return

	if not attacking:
		return

	if not attack_hitbox.monitoring:
		return

	if player_hit_this_attack:
		return


	if area.has_method("take_damage"):

		player_hit_this_attack = true

		area.take_damage(
			damage,
			global_position
		)


		print(
			"ENEMIGO golpeó a ALONSO | Daño: ",
			damage
		)


# ============================================================
# GIRAR HITBOX
# ============================================================

func update_hitbox_direction(facing_left: bool) -> void:

	var hitbox_distance: float = abs(
		attack_hitbox.position.x
	)


	if facing_left:

		attack_hitbox.position.x = -hitbox_distance


	else:

		attack_hitbox.position.x = hitbox_distance


# ============================================================
# RECIBIR DAÑO
# ============================================================

func take_damage(
	damage_received: int,
	attacker_position: Vector2 = Vector2.ZERO
) -> void:

	if dead:
		return


	health -= damage_received

	health = max(
		health,
		0
	)


	print(
		"VIDA ENEMIGO: ",
		health,
		"/",
		max_health
	)


	# --------------------------------------------------------
	# CANCELAR ATAQUE
	# --------------------------------------------------------

	attacking = false

	attack_hitbox.monitoring = false


	# --------------------------------------------------------
	# KO
	# --------------------------------------------------------

	if health <= 0:

		die()

		return


	# --------------------------------------------------------
	# HURT
	# --------------------------------------------------------

	is_hurt = true


	# --------------------------------------------------------
	# RETROCESO
	# --------------------------------------------------------

	if attacker_position != Vector2.ZERO:

		if attacker_position.x < global_position.x:

			global_position.x += knockback_force


		else:

			global_position.x -= knockback_force


	# --------------------------------------------------------
	# ANIMACIÓN HURT
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("hurt"):

		sprite.play("hurt")

		await sprite.animation_finished


	else:

		await get_tree().create_timer(0.20).timeout


	if dead:
		return


	is_hurt = false


	if sprite.sprite_frames.has_animation("idle"):

		sprite.play("idle")


# ============================================================
# KO ENEMIGO
# ============================================================

func die() -> void:

	if dead:
		return


	dead = true

	health = 0

	attacking = false
	can_attack = false
	is_hurt = false

	velocity = Vector2.ZERO

	attack_hitbox.monitoring = false


	print("ENEMIGO KO")


	# Si tienes animación KO úsala.
	if sprite.sprite_frames.has_animation("ko"):

		sprite.play("ko")

		await sprite.animation_finished


	else:

		# Temporalmente usamos hurt.
		if sprite.sprite_frames.has_animation("hurt"):

			sprite.play("hurt")

			await sprite.animation_finished


	# Pequeña pausa antes de desaparecer.
	await get_tree().create_timer(0.35).timeout

	queue_free()
