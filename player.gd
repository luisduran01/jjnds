extends Area2D

signal health_changed(current_health: int)
signal died


# ============================================================
# MOVIMIENTO
# ============================================================

@export var speed: float = 455.0
@export var jump_force: float = 750.0
@export var jump_gravity: float = 1800.0

@export var left_limit: float = 50.0
@export var right_limit: float = 3790.0


# ============================================================
# COMBATE
# ============================================================

@export var max_health: int = 100

@export var jab_damage: int = 10
@export var cross_damage: int = 20

@export var jab_cooldown: float = 0.25
@export var cross_cooldown: float = 0.45

@export var hitbox_delay: float = 0.10
@export var hitbox_active_time: float = 0.12

@export var knockback_force: float = 70.0
@export var invulnerability_time: float = 0.35

# 0.75 = bloquea 75% del daño
@export var block_damage_reduction: float = 0.75


# ============================================================
# VARIABLES
# ============================================================

var health: int = 100

var vertical_velocity: float = 0.0
var ground_y: float = 0.0

var is_jumping: bool = false
var is_attacking: bool = false
var is_blocking: bool = false
var is_hurt: bool = false

var can_attack: bool = true
var invulnerable: bool = false
var dead: bool = false

var current_attack_damage: int = 0

# Evita golpear varias veces durante el mismo puñetazo
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
	ground_y = position.y
	health = max_health

	add_to_group("player")

	attack_hitbox.monitoring = false

	health_changed.emit(health)

	play_animation("idle")


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if dead:
		return

	process_jump(delta)

	if is_hurt:
		return

	# --------------------------------------------------------
	# BLOQUEO
	# --------------------------------------------------------

	if Input.is_action_pressed("bloquear") and not is_attacking and not is_jumping:
		is_blocking = true
		play_animation("block")
		return
	else:
		if is_blocking:
			is_blocking = false
			play_animation("idle")

	# --------------------------------------------------------
	# JAB
	# --------------------------------------------------------

	if Input.is_action_just_pressed("attack"):
		if can_attack and not is_attacking and not is_jumping:
			jab()
			return

	# --------------------------------------------------------
	# CROSS
	# --------------------------------------------------------

	if Input.is_action_just_pressed("attack-dere"):
		if can_attack and not is_attacking and not is_jumping:
			cross()
			return

	# --------------------------------------------------------
	# SALTO
	# --------------------------------------------------------

	if Input.is_action_just_pressed("jump"):
		if not is_jumping and not is_attacking:
			jump()
			return

	# No mover mientras golpea
	if is_attacking:
		return

	# --------------------------------------------------------
	# MOVIMIENTO
	# --------------------------------------------------------

	var direction := Input.get_axis("move_left", "move_right")

	if direction > 0.0:
		sprite.flip_h = false
		update_hitbox_direction(false)

	elif direction < 0.0:
		sprite.flip_h = true
		update_hitbox_direction(true)

	if direction != 0.0:
		position.x += direction * speed * delta

	position.x = clamp(
		position.x,
		left_limit,
		right_limit
	)

	update_movement_animation(direction)


# ============================================================
# ANIMACIONES
# ============================================================

func play_animation(animation_name: String) -> void:
	if sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name:
			sprite.play(animation_name)


func update_movement_animation(direction: float) -> void:
	if dead or is_hurt or is_attacking or is_blocking:
		return

	if is_jumping:
		play_animation("jump")
		return

	if direction != 0.0:
		play_animation("run")
	else:
		play_animation("idle")


# ============================================================
# SALTO
# ============================================================

func jump() -> void:
	if dead:
		return

	if is_jumping:
		return

	if is_attacking:
		return

	if is_hurt:
		return

	if is_blocking:
		return

	is_jumping = true
	vertical_velocity = -jump_force

	play_animation("jump")


func process_jump(delta: float) -> void:
	if not is_jumping:
		return

	vertical_velocity += jump_gravity * delta
	position.y += vertical_velocity * delta

	if position.y >= ground_y:
		position.y = ground_y
		vertical_velocity = 0.0
		is_jumping = false

		if not dead and not is_attacking and not is_hurt:
			play_animation("idle")


# ============================================================
# JAB
# ============================================================

func jab() -> void:
	if dead or is_hurt or is_attacking or is_blocking:
		return

	if not can_attack:
		return

	is_attacking = true
	can_attack = false

	current_attack_damage = jab_damage
	enemies_hit.clear()

	play_animation("attack")

	await execute_punch()

	if dead:
		return

	is_attacking = false

	await get_tree().create_timer(jab_cooldown).timeout

	if dead:
		return

	can_attack = true
	update_animation_after_action()


# ============================================================
# CROSS
# ============================================================

func cross() -> void:
	if dead or is_hurt or is_attacking or is_blocking:
		return

	if not can_attack:
		return

	is_attacking = true
	can_attack = false

	current_attack_damage = cross_damage
	enemies_hit.clear()

	play_animation("cross")

	await execute_punch()

	if dead:
		return

	is_attacking = false

	await get_tree().create_timer(cross_cooldown).timeout

	if dead:
		return

	can_attack = true
	update_animation_after_action()


# ============================================================
# EJECUTAR GOLPE
# ============================================================

func execute_punch() -> void:
	await get_tree().create_timer(hitbox_delay).timeout

	if dead or is_hurt:
		attack_hitbox.monitoring = false
		return

	attack_hitbox.monitoring = true

	# También revisamos las áreas que ya estaban dentro
	# cuando se activó el hitbox.
	for area in attack_hitbox.get_overlapping_areas():
		try_hit_area(area)

	for body in attack_hitbox.get_overlapping_bodies():
		try_hit_body(body)

	await get_tree().create_timer(hitbox_active_time).timeout

	attack_hitbox.monitoring = false

	if dead or is_hurt:
		return

	# Esperar un poco para que termine visualmente el golpe.
	await get_tree().create_timer(0.12).timeout


# ============================================================
# HITBOX
# ============================================================

func _on_attack_hitbox_body_entered(body: Node2D) -> void:
	try_hit_body(body)


func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	try_hit_area(area)


func try_hit_body(body: Node) -> void:
	if dead or not is_attacking:
		return

	if not attack_hitbox.monitoring:
		return

	if body in enemies_hit:
		return

	if body.has_method("take_damage"):
		enemies_hit.append(body)

		body.take_damage(
			current_attack_damage,
			global_position
		)

		print(
			"ALONSO golpeó a ",
			body.name,
			" | Daño: ",
			current_attack_damage
		)


func try_hit_area(area: Area2D) -> void:
	if dead or not is_attacking:
		return

	if not attack_hitbox.monitoring:
		return

	if area == self:
		return

	if area in enemies_hit:
		return

	if area.has_method("take_damage"):
		enemies_hit.append(area)

		area.take_damage(
			current_attack_damage,
			global_position
		)


# ============================================================
# GIRAR HITBOX
# ============================================================

func update_hitbox_direction(facing_left: bool) -> void:
	var hitbox_distance: int = abs(attack_hitbox.position.x)

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
	# BLOQUEO
	# --------------------------------------------------------

	if is_blocking:
		var original_damage := amount

		amount = max(
			1,
			int(round(amount * (1.0 - block_damage_reduction)))
		)

		health -= amount
		health = max(health, 0)

		health_changed.emit(health)

		print(
			"BLOQUEO | Daño original: ",
			original_damage,
			" | Daño recibido: ",
			amount,
			" | Vida: ",
			health
		)

		if health <= 0:
			die()

		return

	# --------------------------------------------------------
	# DAÑO NORMAL
	# --------------------------------------------------------

	health -= amount
	health = max(health, 0)

	health_changed.emit(health)

	print(
		"ALONSO recibió ",
		amount,
		" de daño | Vida: ",
		health,
		"/",
		max_health
	)

	# Cancelar ataque
	is_attacking = false
	can_attack = true

	attack_hitbox.monitoring = false

	if health <= 0:
		die()
		return

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

	play_animation("hurt")

	await get_tree().create_timer(0.25).timeout

	if dead:
		return

	is_hurt = false

	update_animation_after_action()

	await get_tree().create_timer(invulnerability_time).timeout

	if not dead:
		invulnerable = false


# ============================================================
# KO
# ============================================================

func die() -> void:
	if dead:
		return

	dead = true
	health = 0

	is_attacking = false
	is_blocking = false
	is_hurt = false

	can_attack = false
	invulnerable = true

	attack_hitbox.monitoring = false

	health_changed.emit(health)

	print("ALONSO KO")

	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")

	elif sprite.sprite_frames.has_animation("ko"):
		sprite.play("ko")

	else:
		play_animation("hurt")

	died.emit()


# ============================================================
# VOLVER A ANIMACIÓN NORMAL
# ============================================================

func update_animation_after_action() -> void:
	if dead or is_hurt or is_attacking or is_blocking:
		return

	if is_jumping:
		play_animation("jump")
		return

	if Input.is_action_pressed("move_right"):
		sprite.flip_h = false
		update_hitbox_direction(false)
		play_animation("run")
		return

	if Input.is_action_pressed("move_left"):
		sprite.flip_h = true
		update_hitbox_direction(true)
		play_animation("run")
		return

	play_animation("idle")
