extends CharacterBody2D

signal health_changed(health: int)
signal stamina_changed(stamina: float)
signal died
signal knocked_down
signal recovered
signal punch_thrown
signal punch_landed


# ============================================================
# CONFIGURACIÓN
# ============================================================

enum AIState {
	IDLE, APPROACH, ATTACK, COMBO, BLOCK, DODGE, RETREAT, RECOVER, HURT, KO, KNOCKDOWN
}

enum AIStyle {
	OUTBOXER, PRESSURE_FIGHTER, COUNTER_PUNCHER, BRAWLER, BALANCED
}

@export var boxer_profile: BoxerData

@export var ai_style: AIStyle = AIStyle.BALANCED

@export var speed: float = 120.0
@export var attack_distance: float = 100.0
@export var attack_cooldown: float = 1.0

@export var max_health: int = 100
@export var damage: int = 15

@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 15.0
@export var attack_stamina_cost: float = 10.0
@export var block_stamina_drain: float = 10.0
@export var block_damage_reduction: float = 0.75

@export var hitbox_delay: float = 0.15
@export var hitbox_active_time: float = 0.12

@export var knockback_force: float = 60.0


# ============================================================
# VARIABLES
# ============================================================

var health: int = 100
var stamina: float = 100.0
var stamina_recovery_delay: float = 0.0

var player: Node2D = null

var current_state: AIState = AIState.IDLE
var state_timer: float = 0.0
var is_blocking: bool = false

var knockdowns: int = 0
var is_knocked_down: bool = false

var attacking: bool = false
var can_attack: bool = true

var is_hurt: bool = false
var dead: bool = false

# Evita que un mismo ataque golpee varias veces.
var player_hit_this_attack: bool = false
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
	health = max_health
	stamina = max_stamina

func _apply_boxer_profile() -> void:
	if boxer_profile != null:
		max_health = boxer_profile.health
		max_stamina = boxer_profile.stamina_max
		stamina_regen_rate = boxer_profile.stamina_regen_rate
		
		damage = boxer_profile.jab_power
		attack_stamina_cost = boxer_profile.jab_cost
		attack_cooldown = boxer_profile.jab_cooldown
		
		ai_style = boxer_profile.ai_style as AIStyle
	health = max_health
	stamina = max_stamina

	attack_hitbox.monitoring = false

	player = get_tree().get_first_node_in_group("player") as Node2D

	health_changed.emit(health)
	stamina_changed.emit(stamina)

	play_animation("idle")


# ============================================================
# IA DEL ENEMIGO
# ============================================================

func _physics_process(delta: float) -> void:

	process_stamina(delta)

	if dead or is_knocked_down:
		velocity = Vector2.ZERO
		return

	if player == null or not is_instance_valid(player) or player.get("dead") == true:
		velocity = Vector2.ZERO
		play_animation("idle")
		move_and_slide()
		return

	if is_hurt or attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	update_direction_to_player()
	
	state_timer += delta
	think_and_act(delta)
	
	move_and_slide()

func update_direction_to_player() -> void:
	if player.global_position.x < global_position.x:
		sprite.flip_h = true
		update_hitbox_direction(true)
	else:
		sprite.flip_h = false
		update_hitbox_direction(false)

func set_state(new_state: AIState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_timer = 0.0
	is_blocking = (current_state == AIState.BLOCK)

func think_and_act(delta: float) -> void:
	var distance_x = absf(player.global_position.x - global_position.x)
	var player_state_val = player.get("current_state") if player.has_method("get") else -1
	var player_attacking = (player_state_val == 3) # State.ATTACK = 3
	var player_health = player.get("health") if player.has_method("get") else 100

	# --- Determine reaction time based on AI style ---
	var reaction_time: float = 0.20
	var attack_delay: float = 0.40
	var block_chance: float = 0.5
	var combo_chance: float = 0.25

	match ai_style:
		AIStyle.OUTBOXER:
			reaction_time = 0.18
			attack_delay = 0.60
			block_chance = 0.40
			attack_distance = max_health * 0.8  # Fights from range
		AIStyle.PRESSURE_FIGHTER:
			reaction_time = 0.20
			attack_delay = 0.30
			block_chance = 0.25
			combo_chance = 0.55
		AIStyle.COUNTER_PUNCHER:
			reaction_time = 0.12
			attack_delay = 0.55
			block_chance = 0.75
		AIStyle.BRAWLER:
			reaction_time = 0.25
			attack_delay = 0.20
			block_chance = 0.20
			combo_chance = 0.60
		AIStyle.BALANCED:
			pass # defaults

	# --- Low stamina: retreat first ---
	if stamina < max_stamina * 0.2 and current_state != AIState.RECOVER and current_state != AIState.RETREAT:
		set_state(AIState.RETREAT)

	# --- Handle states with early-returns ---
	if current_state == AIState.RETREAT:
		if distance_x > attack_distance * 1.8 or stamina > max_stamina * 0.5:
			set_state(AIState.RECOVER)
		else:
			var dir = -signf(player.global_position.x - global_position.x)
			if dir == 0: dir = 1.0
			velocity.x = dir * speed * 0.75
			play_animation("run")
		return

	if current_state == AIState.RECOVER:
		velocity.x = 0
		play_animation("idle")
		if stamina > max_stamina * 0.65:
			set_state(AIState.IDLE)
		elif player_attacking and distance_x <= attack_distance:
			set_state(AIState.BLOCK)
		return

	# --- Defensive reaction to player attacking nearby ---
	if player_attacking and distance_x <= attack_distance and stamina > block_stamina_drain * 2:
		if state_timer > reaction_time and current_state != AIState.BLOCK and current_state != AIState.RETREAT:
			if randf() < block_chance:
				set_state(AIState.BLOCK)
			else:
				# Try to counter-dodge back
				set_state(AIState.RETREAT)
			return

	if current_state == AIState.BLOCK:
		velocity.x = 0
		if sprite.sprite_frames.has_animation("block"):
			play_animation("block")
		else:
			play_animation("idle")
		# Exit block when player stops attacking
		if not player_attacking and state_timer > 0.4:
			# Counter-attack chance after blocking
			if can_attack and distance_x <= attack_distance and randf() < block_chance:
				set_state(AIState.ATTACK)
			else:
				set_state(AIState.IDLE)
		return

	if current_state == AIState.IDLE:
		velocity.x = 0
		play_animation("idle")
		if state_timer > attack_delay:
			if distance_x > attack_distance * 1.1:
				set_state(AIState.APPROACH)
			elif can_attack and stamina > attack_stamina_cost:
				# Combo: Chain attacks when possible
				if randf() < combo_chance and knockdowns < 2:
					set_state(AIState.COMBO)
				else:
					set_state(AIState.ATTACK)
			else:
				set_state(AIState.APPROACH)
		return

	if current_state == AIState.APPROACH:
		if distance_x <= attack_distance * 0.95:
			if can_attack and stamina > attack_stamina_cost:
				set_state(AIState.ATTACK)
			else:
				set_state(AIState.IDLE)
		else:
			var dir = signf(player.global_position.x - global_position.x)
			if dir == 0: dir = -1.0
			velocity.x = dir * speed
			play_animation("run")
		return

	if current_state == AIState.COMBO:
		velocity.x = 0
		if can_attack:
			attack()
		# After one combo punch, randomly continue or stop
		if randf() < 0.5:
			set_state(AIState.ATTACK)
		else:
			set_state(AIState.IDLE)
		return

	if current_state == AIState.ATTACK:
		velocity.x = 0
		if can_attack:
			attack()
		set_state(AIState.IDLE)

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
		
	if stamina < attack_stamina_cost:
		return

	stamina -= attack_stamina_cost
	stamina_recovery_delay = 1.0
	stamina_changed.emit(stamina)
	
	# Determine punch type based on style or randomly
	if randf() > 0.7:
		last_punch_type = "cross"
	elif randf() > 0.8:
		last_punch_type = "hook"
	else:
		last_punch_type = "jab"
		
	punch_thrown.emit()

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
	if dead or is_hurt or is_knocked_down or is_blocking:
		attack_hitbox.monitoring = false
		attacking = false
		if not dead and not is_knocked_down:
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


	if dead or is_hurt or is_knocked_down or is_blocking:
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
		punch_landed.emit()

		var my_name = boxer_profile.boxer_name if boxer_profile else "Enemy"
		print(
			my_name, " golpeó al jugador | Daño: ",
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

	if is_blocking:
		var original = damage_received
		stamina -= block_stamina_drain
		stamina_recovery_delay = 1.0
		
		if stamina <= 0:
			stamina = 0
			is_blocking = false
			set_state(AIState.IDLE)
			print("ENEMY GUARD BREAK!")
		else:
			damage_received = max(1, int(round(damage_received * (1.0 - block_damage_reduction))))
			
		stamina_changed.emit(stamina)

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
		knockdown()
		return


	# --------------------------------------------------------
	# ESTADO HURT
	# --------------------------------------------------------

	set_state(AIState.HURT)
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
	set_state(AIState.IDLE)

	play_animation("idle")


# ============================================================
# KO Y KNOCKDOWN
# ============================================================

func knockdown() -> void:
	if dead or is_knocked_down:
		return
		
	is_knocked_down = true
	attacking = false
	can_attack = false
	is_hurt = false
	attack_hitbox.monitoring = false
	
	health = 0
	health_changed.emit(health)
	
	knockdowns += 1
	knocked_down.emit()
	
	set_state(AIState.KNOCKDOWN)
	
	# Notify FightManager and pause round timer
	var fm = get_node_or_null("/root/FightManager")
	if fm and fm.has_method("record_knockdown"):
		fm.record_knockdown(false)
	var rm = get_node_or_null("/root/RoundManager")
	if rm and rm.has_method("pause_timer"):
		rm.pause_timer()
	var my_name = boxer_profile.boxer_name if boxer_profile else "Enemy"
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
	is_knocked_down = false
	health = max_health / 3
	stamina = max_stamina / 2
	health_changed.emit(health)
	stamina_changed.emit(stamina)
	can_attack = true
	recovered.emit()
	set_state(AIState.IDLE)
	play_animation("idle")
	# Resume round timer after getting up
	var rm = get_node_or_null("/root/RoundManager")
	if rm and rm.has_method("resume_timer"):
		rm.resume_timer()
	var my_name = boxer_profile.boxer_name if boxer_profile else "Enemy"
	print(my_name, " RECOVERED!")

func die() -> void:

	if dead:
		return

	dead = true
	set_state(AIState.KO)

	health = 0
	
	if not is_knocked_down:
		attacking = false
		can_attack = false
		is_hurt = false
		attack_hitbox.monitoring = false
		health_changed.emit(health)
		if sprite.sprite_frames.has_animation("ko"):
			sprite.play("ko")
		elif sprite.sprite_frames.has_animation("death"):
			sprite.play("death")
		else:
			play_animation("hurt")

	player_hit_this_attack = true

	velocity = Vector2.ZERO

	attack_hitbox.monitoring = false

	# --------------------------------------------------------
	# ACTUALIZAR HUD
	# --------------------------------------------------------

	health_changed.emit(health)

	print("ENEMIGO KO")

	# --------------------------------------------------------
	# AVISAR AL MAIN
	# --------------------------------------------------------

	died.emit()

	print("ENEMIGO DERROTADO")
