extends CharacterBody2D

signal health_changed(health: int)
signal died


# ============================================================
# CONFIGURACIÓN
# ============================================================

@export var speed: float = 120.0

@export var attack_distance: float = 100.0
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

# Evita que un mismo ataque golpee varias veces.
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

	player = get_tree().get_first_node_in_group("player") as Node2D

	health_changed.emit(health)

	play_animation("idle")


# ============================================================
# IA DEL ENEMIGO
# ============================================================

func _physics_process(_delta: float) -> void:

	# --------------------------------------------------------
	# KO
	# --------------------------------------------------------

	if dead:
		velocity = Vector2.ZERO
		return


	# --------------------------------------------------------
	# BUSCAR JUGADOR
	# --------------------------------------------------------

	if player == null or not is_instance_valid(player):

		player = get_tree().get_first_node_in_group("player") as Node2D

		velocity = Vector2.ZERO

		move_and_slide()

		return


	# --------------------------------------------------------
	# JUGADOR DERROTADO
	# --------------------------------------------------------

	if player.get("dead") == true:

		velocity = Vector2.ZERO

		play_animation("idle")

		move_and_slide()

		return


	# --------------------------------------------------------
	# NO MOVERSE MIENTRAS ATACA O RECIBE GOLPE
	# --------------------------------------------------------

	if is_hurt or attacking:

		velocity = Vector2.ZERO

		move_and_slide()

		return


	# --------------------------------------------------------
	# CALCULAR DISTANCIA
	# --------------------------------------------------------

	var distance_x: float = absf(
		player.global_position.x - global_position.x
	)


	# --------------------------------------------------------
	# MIRAR HACIA EL JUGADOR
	# --------------------------------------------------------

	if player.global_position.x < global_position.x:

		sprite.flip_h = true

		update_hitbox_direction(true)

	else:

		sprite.flip_h = false

		update_hitbox_direction(false)


	# --------------------------------------------------------
	# ACERCARSE AL JUGADOR
	# --------------------------------------------------------

	if distance_x > attack_distance:

		var direction: float = signf(
			player.global_position.x - global_position.x
		)

		velocity.x = direction * speed

		play_animation("run")


	# --------------------------------------------------------
	# ATACAR
	# --------------------------------------------------------

	else:

		velocity.x = 0.0

		if can_attack:

			attack()

		else:

			play_animation("idle")


	move_and_slide()


# ============================================================
# REPRODUCIR ANIMACIONES
# ============================================================

func play_animation(animation_name: String) -> void:

	if sprite.sprite_frames.has_animation(animation_name):

		if sprite.animation != animation_name:

			sprite.play(animation_name)


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

	velocity = Vector2.ZERO


	# --------------------------------------------------------
	# ANIMACIÓN ATTACK
	# --------------------------------------------------------

	play_animation("attack")


	# --------------------------------------------------------
	# ESPERAR HASTA EL MOMENTO DEL GOLPE
	# --------------------------------------------------------

	await get_tree().create_timer(
		hitbox_delay
	).timeout


	# Si fue golpeado o murió mientras preparaba el ataque
	if dead or is_hurt:

		attack_hitbox.monitoring = false

		attacking = false

		if not dead:
			can_attack = true

		return


	# --------------------------------------------------------
	# ACTIVAR HITBOX
	# --------------------------------------------------------

	attack_hitbox.monitoring = true


	# Comprobar inmediatamente si el jugador ya está dentro
	for area: Area2D in attack_hitbox.get_overlapping_areas():

		try_hit_player(area)


	# --------------------------------------------------------
	# HITBOX ACTIVA
	# --------------------------------------------------------

	await get_tree().create_timer(
		hitbox_active_time
	).timeout


	# --------------------------------------------------------
	# DESACTIVAR HITBOX
	# --------------------------------------------------------

	attack_hitbox.monitoring = false


	if dead:
		return


	# Pequeño tiempo para terminar visualmente el golpe
	await get_tree().create_timer(0.15).timeout


	if dead:
		return


	attacking = false


	# --------------------------------------------------------
	# VOLVER A IDLE
	# --------------------------------------------------------

	if not is_hurt:

		play_animation("idle")


	# --------------------------------------------------------
	# COOLDOWN
	# --------------------------------------------------------

	await get_tree().create_timer(
		attack_cooldown
	).timeout


	if not dead:

		can_attack = true


# ============================================================
# HITBOX DEL ENEMIGO
# ============================================================

func _on_attack_hitbox_area_entered(area: Area2D) -> void:

	try_hit_player(area)


# ============================================================
# INTENTAR GOLPEAR AL JUGADOR
# ============================================================

func try_hit_player(area: Area2D) -> void:

	if dead:
		return

	if not attacking:
		return

	if not attack_hitbox.monitoring:
		return

	if player_hit_this_attack:
		return


	# --------------------------------------------------------
	# COMPROBAR QUE SEA EL JUGADOR
	# --------------------------------------------------------

	if area.has_method("take_damage"):

		player_hit_this_attack = true

		area.take_damage(
			damage,
			global_position
		)

		print(
			"ENEMIGO golpeó al jugador | Daño: ",
			damage
		)


# ============================================================
# GIRAR HITBOX
# ============================================================

func update_hitbox_direction(facing_left: bool) -> void:

	var hitbox_distance: float = absf(
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


	# --------------------------------------------------------
	# RESTAR VIDA
	# --------------------------------------------------------

	health -= damage_received

	health = maxi(
		health,
		0
	)


	# --------------------------------------------------------
	# ACTUALIZAR HUD
	# --------------------------------------------------------

	health_changed.emit(health)


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

	can_attack = true

	attack_hitbox.monitoring = false


	# --------------------------------------------------------
	# COMPROBAR KO
	# --------------------------------------------------------

	if health <= 0:

		die()

		return


	# --------------------------------------------------------
	# ESTADO HURT
	# --------------------------------------------------------

	is_hurt = true

	velocity = Vector2.ZERO


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

	play_animation("hurt")


	await get_tree().create_timer(
		0.25
	).timeout


	if dead:
		return


	# --------------------------------------------------------
	# TERMINAR HURT
	# --------------------------------------------------------

	is_hurt = false

	play_animation("idle")


# ============================================================
# KO
# ============================================================

func die() -> void:

	if dead:
		return


	dead = true

	health = 0

	attacking = false
	can_attack = false
	is_hurt = false

	player_hit_this_attack = true

	velocity = Vector2.ZERO

	attack_hitbox.monitoring = false


	# --------------------------------------------------------
	# ACTUALIZAR HUD
	# --------------------------------------------------------

	health_changed.emit(health)


	print("ENEMIGO KO")


	# --------------------------------------------------------
	# ANIMACIÓN KO
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("ko"):

		sprite.play("ko")

	elif sprite.sprite_frames.has_animation("death"):

		sprite.play("death")

	elif sprite.sprite_frames.has_animation("hurt"):

		sprite.play("hurt")


	# --------------------------------------------------------
	# AVISAR AL MAIN
	# --------------------------------------------------------

	died.emit()

	print("ENEMIGO DERROTADO")
