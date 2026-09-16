extends Area2D

signal health_changed(current_health: int)
signal died


# ============================================================
# CONFIGURACIÓN - MOVIMIENTO
# ============================================================

@export var speed: float = 455.0
@export var jump_force: float = 750.0
@export var jump_gravity: float = 1800.0

@export var left_limit: float = 50.0
@export var right_limit: float = 3790.0


# ============================================================
# CONFIGURACIÓN - COMBATE
# ============================================================

@export var max_health: int = 100
@export var attack_damage: int = 20

@export var attack_cooldown: float = 0.15
@export var hitbox_delay: float = 0.10
@export var hitbox_active_time: float = 0.12

@export var knockback_force: float = 70.0
@export var invulnerability_time: float = 0.40


# ============================================================
# VARIABLES
# ============================================================

var screen_size: Vector2

var vertical_velocity: float = 0.0
var ground_y: float = 0.0

var health: int = 100

var is_jumping: bool = false
var is_attacking: bool = false
var is_hurt: bool = false

var can_attack: bool = true
var invulnerable: bool = false
var dead: bool = false

# Impide hacer daño varias veces con el mismo golpe.
var enemies_hit: Array[Node] = []


# ============================================================
# NODOS
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	screen_size = get_viewport_rect().size

	ground_y = position.y

	health = max_health

	add_to_group("player")

	if attack_hitbox:
		attack_hitbox.monitoring = false

	health_changed.emit(health)

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:

	# --------------------------------------------------------
	# KO
	# --------------------------------------------------------

	if dead:
		return


	# --------------------------------------------------------
	# ATAQUE
	# --------------------------------------------------------

	if Input.is_action_just_pressed("attack"):
		if can_attack and not is_attacking and not is_hurt:
			attack()


	# --------------------------------------------------------
	# SALTO
	# --------------------------------------------------------

	if Input.is_action_just_pressed("jump"):
		if not is_jumping and not is_hurt and not is_attacking:
			jump()


	# --------------------------------------------------------
	# GRAVEDAD
	# --------------------------------------------------------

	process_jump(delta)


	# --------------------------------------------------------
	# BLOQUEAR MOVIMIENTO DURANTE HURT
	# --------------------------------------------------------

	if is_hurt:
		return


	# --------------------------------------------------------
	# BLOQUEAR MOVIMIENTO DURANTE ATAQUE
	# --------------------------------------------------------

	if is_attacking:
		return


	# --------------------------------------------------------
	# MOVIMIENTO
	# --------------------------------------------------------

	var direction: float = Input.get_axis(
		"move_left",
		"move_right"
	)


	# --------------------------------------------------------
	# GIRAR PERSONAJE
	# --------------------------------------------------------

	if direction > 0.0:
		sprite.flip_h = false
		update_hitbox_direction(false)

	elif direction < 0.0:
		sprite.flip_h = true
		update_hitbox_direction(true)


	# --------------------------------------------------------
	# MOVER
	# --------------------------------------------------------

	if direction != 0.0:
		position.x += direction * speed * delta


	# --------------------------------------------------------
	# LÍMITES
	# --------------------------------------------------------

	position.x = clamp(
		position.x,
		left_limit,
		right_limit
	)


	# --------------------------------------------------------
	# ANIMACIONES
	# --------------------------------------------------------

	update_movement_animation(direction)


# ============================================================
# ANIMACIÓN DE MOVIMIENTO
# ============================================================

func update_movement_animation(direction: float) -> void:

	if dead or is_hurt or is_attacking:
		return

	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):
			if sprite.animation != "jump":
				sprite.play("jump")

		return


	if direction != 0.0:

		if sprite.sprite_frames.has_animation("run"):
			if sprite.animation != "run":
				sprite.play("run")

		return


	if sprite.sprite_frames.has_animation("idle"):

		if sprite.animation != "idle":
			sprite.play("idle")


# ============================================================
# SALTO
# ============================================================

func jump() -> void:

	if dead:
		return

	if is_jumping:
		return

	if is_hurt:
		return

	is_jumping = true

	vertical_velocity = -jump_force

	if sprite.sprite_frames.has_animation("jump"):
		sprite.play("jump")


# ============================================================
# GRAVEDAD / SALTO
# ============================================================

func process_jump(delta: float) -> void:

	if not is_jumping:
		return

	vertical_velocity += jump_gravity * delta

	position.y += vertical_velocity * delta


	# --------------------------------------------------------
	# TOCAR SUELO
	# --------------------------------------------------------

	if position.y >= ground_y:

		position.y = ground_y

		vertical_velocity = 0.0

		is_jumping = false

		if not is_attacking and not is_hurt and not dead:

			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")


# ============================================================
# ATAQUE
# ============================================================

func attack() -> void:

	if dead:
		return

	if not can_attack:
		return

	if is_attacking:
		return

	if is_hurt:
		return


	is_attacking = true
	can_attack = false

	enemies_hit.clear()


	# --------------------------------------------------------
	# ANIMACIÓN ATTACK
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("attack"):
		sprite.play("attack")


	# --------------------------------------------------------
	# ESPERAR MOMENTO DEL PUÑETAZO
	# --------------------------------------------------------

	await get_tree().create_timer(
		hitbox_delay
	).timeout


	# Alonso pudo recibir daño durante la espera.
	if dead or is_hurt:

		if attack_hitbox:
			attack_hitbox.monitoring = false

		is_attacking = false

		if not dead:
			can_attack = true

		return


	# --------------------------------------------------------
	# ACTIVAR HITBOX
	# --------------------------------------------------------

	if attack_hitbox:
		attack_hitbox.monitoring = true


	await get_tree().create_timer(
		hitbox_active_time
	).timeout


	# --------------------------------------------------------
	# DESACTIVAR HITBOX
	# --------------------------------------------------------

	if attack_hitbox:
		attack_hitbox.monitoring = false


	# --------------------------------------------------------
	# ESPERAR ANIMACIÓN
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("attack"):

		if sprite.animation == "attack":
			await sprite.animation_finished


	is_attacking = false


	# --------------------------------------------------------
	# COOLDOWN
	# --------------------------------------------------------

	await get_tree().create_timer(
		attack_cooldown
	).timeout


	if dead:
		return


	can_attack = true

	update_animation_after_action()


# ============================================================
# HITBOX DEL ATAQUE
# ============================================================

func _on_attack_hitbox_body_entered(body: Node2D) -> void:

	if dead:
		return

	if not is_attacking:
		return

	if not attack_hitbox.monitoring:
		return

	if body in enemies_hit:
		return


	if body.has_method("take_damage"):

		enemies_hit.append(body)

		body.take_damage(
			attack_damage,
			global_position
		)

		print(
			"ALONSO golpeó a ",
			body.name,
			" | Daño: ",
			attack_damage
		)


# ============================================================
# GIRAR HITBOX
# ============================================================

func update_hitbox_direction(facing_left: bool) -> void:

	if not attack_hitbox:
		return

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
	amount: int,
	attacker_position: Vector2 = Vector2.ZERO
) -> void:

	if dead:
		return

	if invulnerable:
		return


	# --------------------------------------------------------
	# RESTAR VIDA
	# --------------------------------------------------------

	health -= amount

	health = max(
		health,
		0
	)

	health_changed.emit(health)


	print(
		"ALONSO recibió ",
		amount,
		" de daño | Vida: ",
		health,
		"/",
		max_health
	)


	# --------------------------------------------------------
	# CANCELAR ATAQUE
	# --------------------------------------------------------

	is_attacking = false

	if attack_hitbox:
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
	invulnerable = true


	# --------------------------------------------------------
	# KNOCKBACK
	# --------------------------------------------------------

	if attacker_position != Vector2.ZERO:

		if attacker_position.x < global_position.x:

			position.x += knockback_force

		else:

			position.x -= knockback_force


	position.x = clamp(
		position.x,
		left_limit,
		right_limit
	)


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

	update_animation_after_action()


	# --------------------------------------------------------
	# INVULNERABILIDAD TEMPORAL
	# --------------------------------------------------------

	await get_tree().create_timer(
		invulnerability_time
	).timeout


	if not dead:
		invulnerable = false


# ============================================================
# KO / MUERTE
# ============================================================

func die() -> void:

	if dead:
		return


	dead = true

	health = 0

	is_attacking = false
	is_hurt = false

	can_attack = false
	invulnerable = true


	if attack_hitbox:
		attack_hitbox.monitoring = false


	health_changed.emit(health)


	print("ALONSO KO")


	# --------------------------------------------------------
	# ANIMACIÓN DE MUERTE
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("death"):

		sprite.play("death")

		await sprite.animation_finished


	elif sprite.sprite_frames.has_animation("ko"):

		sprite.play("ko")

		await sprite.animation_finished


	elif sprite.sprite_frames.has_animation("hurt"):

		sprite.play("hurt")

		await sprite.animation_finished


	died.emit()

	print("ALONSO HA SIDO DERROTADO")


# ============================================================
# ACTUALIZAR ANIMACIÓN DESPUÉS DE UNA ACCIÓN
# ============================================================

func update_animation_after_action() -> void:

	if dead:
		return

	if is_hurt:
		return

	if is_attacking:
		return


	# --------------------------------------------------------
	# SALTO
	# --------------------------------------------------------

	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):
			sprite.play("jump")

		return


	# --------------------------------------------------------
	# DERECHA
	# --------------------------------------------------------

	if Input.is_action_pressed("move_right"):

		sprite.flip_h = false

		update_hitbox_direction(false)

		if sprite.sprite_frames.has_animation("run"):
			sprite.play("run")

		return


	# --------------------------------------------------------
	# IZQUIERDA
	# --------------------------------------------------------

	if Input.is_action_pressed("move_left"):

		sprite.flip_h = true

		update_hitbox_direction(true)

		if sprite.sprite_frames.has_animation("run"):
			sprite.play("run")

		return


	# --------------------------------------------------------
	# IDLE
	# --------------------------------------------------------

	if sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
