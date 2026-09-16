extends Area2D

# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var speed: float = 455.0

@export var jump_force: float = 750.0
@export var jump_gravity: float = 1800.0

@export var left_limit: float = 50.0
@export var right_limit: float = 3790.0

@export var attack_cooldown: float = 0.15
@export var attack_damage: int = 20

# Momento en que el puño empieza a hacer daño.
@export var hitbox_delay: float = 0.10

# Tiempo durante el cual el golpe está activo.
@export var hitbox_active_time: float = 0.12

@export var max_health: int = 100
@export var enemy_damage: int = 15
@export var knockback_force: float = 70.0

var health: int = 100
var invulnerable: bool = false
var dead: bool = false
# ==========================================
# VARIABLES
# ==========================================

var screen_size: Vector2

var vertical_velocity: float = 0.0
var ground_y: float

var is_jumping: bool = false
var is_attacking: bool = false
var is_hurt: bool = false

var can_attack: bool = true

# Evita hacer daño varias veces al mismo enemigo
# durante un solo golpe.
var enemies_hit: Array[Node] = []


# ==========================================
# NODOS
# ==========================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	screen_size = get_viewport_rect().size

	ground_y = position.y

	sprite.play("idle")

	# El puño empieza desactivado.
	attack_hitbox.monitoring = false


# ==========================================
# PROCESS
# ==========================================

func _process(delta: float) -> void:

	# ------------------------------------------
	# ATAQUE
	# ------------------------------------------

	if Input.is_action_just_pressed("attack"):

		if can_attack and not is_attacking and not is_hurt:

			attack()


	# ------------------------------------------
	# SALTO
	# ------------------------------------------

	if Input.is_action_just_pressed("jump"):

		if not is_jumping and not is_hurt:

			jump()


	# ------------------------------------------
	# GRAVEDAD
	# ------------------------------------------

	process_jump(delta)


	# ------------------------------------------
	# RECIBIENDO DAÑO
	# ------------------------------------------

	if is_hurt:
		return


	# ------------------------------------------
	# ATACANDO
	# ------------------------------------------

	if is_attacking:
		return


	# ------------------------------------------
	# MOVIMIENTO
	# ------------------------------------------

	var direction: float = Input.get_axis(
		"move_left",
		"move_right"
	)


	# ------------------------------------------
	# DIRECCIÓN DEL PERSONAJE
	# ------------------------------------------

	if direction > 0:

		sprite.flip_h = false
		update_hitbox_direction(false)


	elif direction < 0:

		sprite.flip_h = true
		update_hitbox_direction(true)


	# ------------------------------------------
	# MOVIMIENTO HORIZONTAL
	# ------------------------------------------

	if direction != 0:

		position.x += direction * speed * delta


	# ------------------------------------------
	# LÍMITES DEL NIVEL
	# ------------------------------------------

	position.x = clamp(
		position.x,
		left_limit,
		right_limit
	)


	# ------------------------------------------
	# ANIMACIONES
	# ------------------------------------------

	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):

			if sprite.animation != "jump":

				sprite.play("jump")


	elif direction != 0:

		if sprite.animation != "run":

			sprite.play("run")


	else:

		if sprite.animation != "idle":

			sprite.play("idle")


# ==========================================
# SALTO
# ==========================================

func jump() -> void:

	if is_jumping:
		return


	is_jumping = true

	vertical_velocity = -jump_force


	if sprite.sprite_frames.has_animation("jump"):

		sprite.play("jump")


# ==========================================
# GRAVEDAD
# ==========================================

func process_jump(delta: float) -> void:

	if not is_jumping:
		return


	# IMPORTANTE:
	# aquí usamos jump_gravity y no "gravity".
	vertical_velocity += jump_gravity * delta


	position.y += vertical_velocity * delta


	# ------------------------------------------
	# TOCAR EL SUELO
	# ------------------------------------------

	if position.y >= ground_y:

		position.y = ground_y

		vertical_velocity = 0.0

		is_jumping = false


		if not is_attacking and not is_hurt:

			sprite.play("idle")


# ==========================================
# ATAQUE
# ==========================================

func attack() -> void:

	if not can_attack:
		return


	if is_attacking:
		return


	is_attacking = true
	can_attack = false

	enemies_hit.clear()


	# ------------------------------------------
	# ANIMACIÓN
	# ------------------------------------------

	sprite.play("attack")


	# Esperar hasta el frame donde sale el puño.
	await get_tree().create_timer(
		hitbox_delay
	).timeout


	# Si recibimos daño mientras atacábamos,
	# cancelamos el golpe.
	if is_hurt:

		attack_hitbox.monitoring = false

		is_attacking = false

		return


	# ------------------------------------------
	# ACTIVAR PUÑO
	# ------------------------------------------

	attack_hitbox.monitoring = true


	await get_tree().create_timer(
		hitbox_active_time
	).timeout


	# ------------------------------------------
	# DESACTIVAR PUÑO
	# ------------------------------------------

	attack_hitbox.monitoring = false


	# Esperar el resto de la animación.
	if sprite.animation == "attack":

		await sprite.animation_finished


	is_attacking = false


	# ------------------------------------------
	# COOLDOWN
	# ------------------------------------------

	await get_tree().create_timer(
		attack_cooldown
	).timeout


	can_attack = true


	# ------------------------------------------
	# VOLVER A ANIMACIÓN NORMAL
	# ------------------------------------------

	update_animation_after_action()


# ==========================================
# HITBOX DEL PUÑO
# ==========================================

func _on_attack_hitbox_body_entered(body: Node2D) -> void:

	if not is_attacking:
		return


	if body in enemies_hit:
		return


	if body.has_method("take_damage"):

		enemies_hit.append(body)

		body.take_damage(attack_damage)

		print(
			"Alonso golpeó a ",
			body.name,
			" por ",
			attack_damage,
			" de daño."
		)


# ==========================================
# GIRAR HITBOX
# ==========================================

func update_hitbox_direction(facing_left: bool) -> void:

	var hitbox_x: float = abs(
		attack_hitbox.position.x
	)


	if facing_left:

		attack_hitbox.position.x = -hitbox_x

	else:

		attack_hitbox.position.x = hitbox_x


# ==========================================
# RECIBIR DAÑO
# ==========================================

func hurt() -> void:

	if is_hurt:
		return


	is_hurt = true
	is_attacking = false

	# Si estaba golpeando, cancelar hitbox.
	attack_hitbox.monitoring = false


	sprite.play("hurt")


	await sprite.animation_finished


	is_hurt = false


	update_animation_after_action()


# ==========================================
# ACTUALIZAR ANIMACIÓN
# ==========================================

func update_animation_after_action() -> void:

	if is_hurt:
		return


	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):

			sprite.play("jump")

		return


	if Input.is_action_pressed("move_right"):

		sprite.flip_h = false
		update_hitbox_direction(false)

		sprite.play("run")

		return


	if Input.is_action_pressed("move_left"):

		sprite.flip_h = true
		update_hitbox_direction(true)

		sprite.play("run")

		return


	sprite.play("idle")
