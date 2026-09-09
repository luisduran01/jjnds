extends Area2D

# ==========================================
# CONFIGURACIÓN
# ==========================================

@export var speed: float = 455.0

@export var jump_force: float = 750.0
@export var jump_gravity: float = 1800.0

@export var left_limit: float = 50.0
@export var right_limit: float = 1230.0

@export var attack_cooldown: float = 0.15


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


# ==========================================
# SPRITE
# ==========================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# ==========================================
# READY
# ==========================================

func _ready() -> void:

	screen_size = get_viewport_rect().size

	# Guarda la posición original del suelo
	ground_y = position.y

	# Animación inicial
	sprite.play("idle")


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
	# GRAVEDAD / SALTO
	# ------------------------------------------

	process_jump(delta)


	# ------------------------------------------
	# SI RECIBE DAÑO
	# ------------------------------------------

	if is_hurt:
		return


	# ------------------------------------------
	# SI ESTÁ ATACANDO
	# ------------------------------------------

	if is_attacking:

		# Permitimos que siga cayendo si atacó en el aire
		return


	# ------------------------------------------
	# MOVIMIENTO HORIZONTAL
	# ------------------------------------------

	var direction: float = 0.0


	if Input.is_action_pressed("move_right"):

		direction += 1.0


	if Input.is_action_pressed("move_left"):

		direction -= 1.0


	# ------------------------------------------
	# GIRAR PERSONAJE
	# ------------------------------------------

	if direction > 0:

		sprite.flip_h = false


	elif direction < 0:

		sprite.flip_h = true


	# ------------------------------------------
	# MOVER PERSONAJE
	# ------------------------------------------

	if direction != 0:

		position.x += direction * speed * delta


	# ------------------------------------------
	# LÍMITES DE PANTALLA
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
# SALTAR
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


	# Aplicar gravedad
	vertical_velocity += gravity * delta


	# Mover verticalmente
	position.y += vertical_velocity * delta


	# Cuando toca el suelo
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


	sprite.play("attack")


	# Esperar que termine la animación
	await sprite.animation_finished


	is_attacking = false


	# Cooldown pequeño para evitar spam
	await get_tree().create_timer(attack_cooldown).timeout


	can_attack = true


	# Elegir animación después del ataque
	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):

			sprite.play("jump")


	elif Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left"):

		sprite.play("run")


	else:

		sprite.play("idle")


# ==========================================
# RECIBIR DAÑO
# ==========================================

func hurt() -> void:

	if is_hurt:
		return


	is_hurt = true

	is_attacking = false


	sprite.play("hurt")


	await sprite.animation_finished


	is_hurt = false


	if is_jumping:

		if sprite.sprite_frames.has_animation("jump"):

			sprite.play("jump")


	else:

		sprite.play("idle")
