extends Area2D

signal health_changed(current_health: int)
signal stamina_changed(current_stamina: float)
signal died
signal knocked_down
signal recovered
signal punch_thrown
signal punch_landed


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

@export var boxer_profile: BoxerData

@export var max_health: int = 100
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 20.0
@export var block_stamina_drain: float = 15.0 # Por impacto

@export var jab_damage: int = 10
@export var jab_stamina_cost: float = 8.0
@export var jab_cooldown: float = 0.25

@export var cross_damage: int = 20
@export var cross_stamina_cost: float = 15.0
@export var cross_cooldown: float = 0.45

@export var hook_damage: int = 25
@export var hook_stamina_cost: float = 20.0
@export var hook_cooldown: float = 0.5

@export var uppercut_damage: int = 30
@export var uppercut_stamina_cost: float = 25.0
@export var uppercut_cooldown: float = 0.6

@export var body_shot_damage: int = 15
@export var body_shot_stamina_cost: float = 12.0
@export var body_shot_cooldown: float = 0.4

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
var stamina: float = 100.0
var stamina_recovery_delay: float = 0.0
var combo_window: float = 0.0

var knockdowns: int = 0
var is_knocked_down: bool = false

var vertical_velocity: float = 0.0
var ground_y: float = 0.0

enum State { IDLE, MOVE, JUMP, ATTACK, BLOCK, HURT, KNOCKDOWN, KO }
var current_state: State = State.IDLE

var is_jumping: bool = false
var is_attacking: bool = false
var is_blocking: bool = false
var is_hurt: bool = false

var can_attack: bool = true
var invulnerable: bool = false
var dead: bool = false

func set_state(new_state: State) -> void:
	current_state = new_state
	is_jumping = (new_state == State.JUMP)
	is_attacking = (new_state == State.ATTACK)
	is_blocking = (new_state == State.BLOCK)
	is_hurt = (new_state == State.HURT)
	is_knocked_down = (new_state == State.KNOCKDOWN)
	dead = (new_state == State.KO)

var current_attack_damage: int = 0

# Evita golpear varias veces durante el mismo puñetazo
var enemies_hit: Array[Node] = []

var input_buffer: String = ""
var input_buffer_time: float = 0.0
const BUFFER_MAX_TIME: float = 0.25
var last_punch_type: String = "jab"


# ============================================================
# NODOS
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_hitbox: Area2D = $AttackHitbox


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	_apply_boxer_profile()
	ground_y = position.y
	health = max_health
	stamina = max_stamina

func _apply_boxer_profile() -> void:
	if boxer_profile == null:
		return
	max_health = boxer_profile.health
	max_stamina = boxer_profile.stamina_max
	stamina_regen_rate = boxer_profile.stamina_regen_rate
	
	jab_damage = boxer_profile.jab_power
	jab_stamina_cost = boxer_profile.jab_cost
	jab_cooldown = boxer_profile.jab_cooldown
	
	cross_damage = boxer_profile.cross_power
	cross_stamina_cost = boxer_profile.cross_cost
	cross_cooldown = boxer_profile.cross_cooldown
	
	hook_damage = boxer_profile.hook_power
	hook_stamina_cost = boxer_profile.hook_cost
	hook_cooldown = boxer_profile.hook_cooldown
	
	uppercut_damage = boxer_profile.uppercut_power
	uppercut_stamina_cost = boxer_profile.uppercut_cost
	uppercut_cooldown = boxer_profile.uppercut_cooldown
	
	body_shot_damage = boxer_profile.body_shot_power
	body_shot_stamina_cost = boxer_profile.body_shot_cost
	body_shot_cooldown = boxer_profile.body_shot_cooldown
	
	# Sync health/stamina to new max values
	health  = max_health
	stamina = max_stamina

	add_to_group("player")

	attack_hitbox.monitoring = false

	health_changed.emit(health)
	stamina_changed.emit(stamina)

	play_animation("idle")


# ============================================================
# PROCESS
# ============================================================

func _process(delta: float) -> void:
	if dead:
		return

	process_jump(delta)
	process_stamina(delta)

	if is_hurt or is_knocked_down:
		return

	if combo_window > 0:
		combo_window -= delta

	# --------------------------------------------------------
	# BLOQUEO
	# --------------------------------------------------------

	if Input.is_action_pressed("bloquear") and not is_attacking and not is_jumping and not is_hurt:
		set_state(State.BLOCK)
		play_animation("block")
		return
	else:
		if is_blocking:
			set_state(State.IDLE)
			play_animation("idle")

	# --------------------------------------------------------
	# ATAQUES
	# --------------------------------------------------------

	if input_buffer_time > 0:
		input_buffer_time -= delta
		if input_buffer_time <= 0:
			input_buffer = ""
	
	if Input.is_action_just_pressed("attack"):
		input_buffer = "attack"
		input_buffer_time = BUFFER_MAX_TIME
	elif Input.is_action_just_pressed("attack-dere"):
		input_buffer = "attack-dere"
		input_buffer_time = BUFFER_MAX_TIME
	
	if can_attack and not is_attacking and not is_jumping and input_buffer != "":
		var up_pressed = Input.is_action_pressed("move_up") if InputMap.has_action("move_up") else Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W)
		var down_pressed = Input.is_action_pressed("move_down") if InputMap.has_action("move_down") else Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S)
		
		var buf = input_buffer
		input_buffer = ""
		input_buffer_time = 0.0
		
		if buf == "attack":
			if up_pressed:
				uppercut()
			elif down_pressed:
				body_shot()
			else:
				jab()
			return
			
		elif buf == "attack-dere":
			if up_pressed:
				hook()
			else:
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

	set_state(State.JUMP)
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
		set_state(State.IDLE)

		if not dead and not is_attacking and not is_hurt:
			play_animation("idle")


# ============================================================
# SISTEMA DE COMBATE
# ============================================================

func perform_attack(anim: String, damage: int, cost: float, cooldown: float) -> void:
	if dead or is_hurt or is_attacking or is_blocking:
		return
	if not can_attack or stamina < cost:
		return
		
	stamina -= cost
	stamina_recovery_delay = 1.0 # Pause recovery
	stamina_changed.emit(stamina)
	
	punch_thrown.emit()
	
	set_state(State.ATTACK)
	can_attack = false
	current_attack_damage = damage
	enemies_hit.clear()
	
	play_animation(anim)
	await execute_punch()
	
	if dead: return
	set_state(State.IDLE)
	
	var actual_cooldown = cooldown
	if combo_window > 0:
		actual_cooldown *= 0.7 # 30% faster if in combo
		
	combo_window = 0.5 # Window for next combo
	
	await get_tree().create_timer(actual_cooldown).timeout
	if dead: return
	
	can_attack = true
	update_animation_after_action()

func jab() -> void:
	last_punch_type = "jab"
	perform_attack("attack", jab_damage, jab_stamina_cost, jab_cooldown)

func cross() -> void:
	last_punch_type = "cross"
	perform_attack("cross", cross_damage, cross_stamina_cost, cross_cooldown)

func hook() -> void:
	last_punch_type = "hook"
	# Use cross animation for now if hook doesn't exist
	perform_attack("cross", hook_damage, hook_stamina_cost, hook_cooldown)

func uppercut() -> void:
	last_punch_type = "uppercut"
	perform_attack("attack", uppercut_damage, uppercut_stamina_cost, uppercut_cooldown)
	
func body_shot() -> void:
	last_punch_type = "body"
	perform_attack("attack", body_shot_damage, body_shot_stamina_cost, body_shot_cooldown)

func process_stamina(delta: float) -> void:
	if stamina_recovery_delay > 0:
		stamina_recovery_delay -= delta
	else:
		if stamina < max_stamina:
			stamina += stamina_regen_rate * delta
			if stamina > max_stamina:
				stamina = max_stamina
			stamina_changed.emit(stamina)


# ============================================================
# EJECUTAR GOLPE
# ============================================================

func execute_punch() -> void:
	await get_tree().create_timer(hitbox_delay).timeout

	if dead or is_hurt or is_knocked_down or is_blocking:
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

	if dead or is_hurt or is_knocked_down or is_blocking:
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
		punch_landed.emit()

		var my_name = boxer_profile.boxer_name if boxer_profile else "Player"
		print(
			my_name, " golpeó a ",
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
		punch_landed.emit()


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
		
		# Consumir stamina por el impacto
		stamina -= block_stamina_drain
		stamina_recovery_delay = 1.0
		
		if stamina <= 0:
			stamina = 0
			# Guard break
			set_state(State.IDLE)
			amount = original_damage # Recibe daño completo
			print("GUARD BREAK!")
		else:
			amount = max(
				1,
				int(round(amount * (1.0 - block_damage_reduction)))
			)
			
		stamina_changed.emit(stamina)

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

	var my_name = boxer_profile.boxer_name if boxer_profile else "Player"
	print(
		my_name, " recibió ",
		amount,
		" de daño | Vida: ",
		health,
		"/",
		max_health
	)

	# Cancelar ataque
	set_state(State.HURT)
	can_attack = true

	attack_hitbox.monitoring = false

	if health <= 0:
		knockdown()
		return

	set_state(State.HURT)
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

	set_state(State.IDLE)

	update_animation_after_action()

	await get_tree().create_timer(invulnerability_time).timeout

	if not dead:
		invulnerable = false


# ============================================================
# KO Y KNOCKDOWN
# ============================================================

func knockdown() -> void:
	if dead or is_knocked_down:
		return
		
	set_state(State.KNOCKDOWN)
	can_attack = false
	invulnerable = true
	attack_hitbox.monitoring = false
	
	health = 0
	health_changed.emit(health)
	
	knockdowns += 1
	knocked_down.emit()
	
	# Notify FightManager and pause timer during count
	var fm = get_node_or_null("/root/FightManager")
	if fm and fm.has_method("record_knockdown"):
		fm.record_knockdown(true)
	var rm = get_node_or_null("/root/RoundManager")
	if rm and rm.has_method("pause_timer"):
		rm.pause_timer()
	
	var my_name = boxer_profile.boxer_name if boxer_profile else "Player"
	print(my_name, " KNOCKDOWN!")
	
	if sprite.sprite_frames.has_animation("ko"):
		sprite.play("ko")
	elif sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		play_animation("hurt")
		
	attempt_recovery()

func attempt_recovery() -> void:
	for i in range(1, 11):
		await get_tree().create_timer(1.0).timeout
		if dead: return
		print("Referee count: ", i)
		if i == 8:
			var chance = 1.0 - (knockdowns * 0.25)
			if randf() < chance and knockdowns < 3:
				recover()
				return
	die()

func recover() -> void:
	set_state(State.IDLE)
	health = max_health / 3
	stamina = max_stamina / 2
	health_changed.emit(health)
	stamina_changed.emit(stamina)
	invulnerable = false
	can_attack = true
	recovered.emit()
	play_animation("idle")
	# Resume round timer after getting up
	var rm = get_node_or_null("/root/RoundManager")
	if rm and rm.has_method("resume_timer"):
		rm.resume_timer()
	var my_name = boxer_profile.boxer_name if boxer_profile else "Player"
	print(my_name, " RECOVERED!")

func die() -> void:
	if dead:
		return

	set_state(State.KO)
	health = 0
	
	if not is_knocked_down:
		can_attack = false
		invulnerable = true
		attack_hitbox.monitoring = false
		health_changed.emit(health)
		if sprite.sprite_frames.has_animation("ko"):
			sprite.play("ko")
		elif sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
		else:
			play_animation("hurt")
			
	print("ALONSO KO")
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
