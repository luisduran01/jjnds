extends CharacterBody3D

@export var is_player: bool = true
var target: CharacterBody3D

var health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

@onready var anim_tree = $AnimationTree
@onready var playback = anim_tree.get("parameters/playback") if anim_tree else null
@onready var model: Node3D = $Model

var is_attacking: bool = false
var is_blocking: bool = false
var is_hurt: bool = false

var move_speed: float = 3.5
var rotation_speed: float = 14.0

var step_cooldown: float = 0.0
var step_duration: float = 0.2
var is_stepping: bool = false
var step_velocity: Vector3 = Vector3.ZERO
var is_dodging: bool = false
var move_input := Vector2.ZERO
var footwork_velocity := Vector3.ZERO
var punch_kind := ""
var punch_clock := 0.0
var punch_length := 0.0
var body_roll := 0.0
var body_pitch := 0.0
var body_shift := Vector3.ZERO

signal health_changed(new_val)
signal stamina_changed(new_val)

func _ready() -> void:
	_load_stats()
	# Find target
	for node in get_tree().get_nodes_in_group("player" if not is_player else "enemy"):
		if node is CharacterBody3D:
			target = node
			break

func _load_stats() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		var profile = gm.player_profile if is_player else gm.enemy_profile
		if profile:
			max_stamina = profile.stamina_max
			stamina = max_stamina
			health = 100 + (profile.chin * 0.5)
			move_speed = 1.5 + (profile.speed * 0.02)
			
	# Update HUD immediately
	health_changed.emit(health)
	stamina_changed.emit(stamina)

var is_exhausted: bool = false
var stamina_regen_rate: float = 15.0

func _physics_process(delta: float) -> void:
	if is_hurt: return
	
	_handle_rotation(delta)
	_handle_movement(delta)
	
	if is_player:
		_handle_input()
	else:
		_handle_ai(delta)
		
	# Stamina Regeneration
	if not is_attacking and not is_stepping and not is_dodging and step_cooldown <= 0:
		var regen = stamina_regen_rate
		if is_blocking: regen *= 0.2
		stamina = min(max_stamina, stamina + regen * delta)
		stamina_changed.emit(stamina)
		
	is_exhausted = stamina < (max_stamina * 0.2)
	if is_exhausted and playback and not is_attacking and not is_hurt and not is_dodging:
		# Could trigger a heavy breathing anim here
		pass
		
	# Basic gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	move_and_slide()
	_update_boxer_pose(delta)

func _handle_movement(delta: float) -> void:
	if step_cooldown > 0:
		step_cooldown -= delta

	if is_dodging:
		velocity = step_velocity
		return
		
	var input_dir = Vector2.ZERO
	if is_player:
		input_dir = Input.get_vector("box_left", "box_right", "box_forward", "box_back")
	move_input = input_dir
		
	var current_move_speed = move_speed
	if is_exhausted:
		current_move_speed *= 0.6 # Move slower when exhausted
		
	if input_dir.length() > 0.1 and not is_attacking:
		# The fighter always faces the rival, so local X circles and local Z closes/ranges.
		var local_direction = Vector3(input_dir.x, 0, input_dir.y).normalized()
		var direction = (global_basis * local_direction).normalized()
		var target_speed = current_move_speed * (0.86 if absf(input_dir.x) > 0.1 else 1.0)
		footwork_velocity = footwork_velocity.lerp(direction * target_speed, minf(1.0, delta * 9.0))
		velocity.x = footwork_velocity.x
		velocity.z = footwork_velocity.z
		is_stepping = true
		if playback: playback.travel("walk")
	else:
		if is_attacking:
			# Allow slight movement during attacks if pressing direction
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = direction.x * (move_speed * 0.3)
			velocity.z = direction.z * (move_speed * 0.3)
		else:
			footwork_velocity = footwork_velocity.move_toward(Vector3.ZERO, delta * move_speed * 7.0)
			velocity.x = footwork_velocity.x
			velocity.z = footwork_velocity.z
			is_stepping = footwork_velocity.length() > 0.08
			if playback and not is_blocking: 
				playback.travel("idle")

func _handle_rotation(delta: float) -> void:
	if target and not is_hurt:
		var target_pos = target.global_position
		target_pos.y = global_position.y
		var look_dir = target_pos - global_position
		if look_dir.length_squared() > 0.1:
			var target_transform = global_transform.looking_at(target_pos, Vector3.UP)
			global_transform = global_transform.interpolate_with(target_transform, rotation_speed * delta)

func _handle_input() -> void:
	if is_attacking or is_blocking or is_dodging: return
	
	if Input.is_action_just_pressed("box_jab"):
		punch("jab")
	elif Input.is_action_just_pressed("box_cross"):
		punch("cross")
		
	# Placeholder dodge input (e.g., right click or shift)
	if Input.is_action_just_pressed("bloquear"): # You can change this to a specific dodge action
		if Input.get_vector("box_left", "box_right", "box_forward", "box_back").length() > 0.1:
			dodge()

func dodge() -> void:
	if stamina < 15: return
	stamina -= 15
	stamina_changed.emit(stamina)
	is_dodging = true
	var input_dir = Input.get_vector("box_left", "box_right", "box_forward", "box_back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	step_velocity = direction * (move_speed * 2.0)
	step_cooldown = 0.35
	if playback: playback.travel("slip") # Ideally slip_left or slip_right
	
	await get_tree().create_timer(0.35).timeout
	is_dodging = false

func _handle_ai(delta: float) -> void:
	pass # AI logic placeholder

func punch(type: String) -> void:
	if stamina < 5: return # Need at least 5 to punch
	is_attacking = true
	
	# Punch costs more if you are already exhausted
	var cost = 10.0 if not is_exhausted else 15.0
	stamina = max(0, stamina - cost)
	stamina_changed.emit(stamina)
	
	if playback:
		playback.travel(type)
	
	punch_kind = type
	punch_clock = 0.0
	punch_length = 0.42 if type == "jab" else 0.58
	var attack_speed = punch_length
	if is_exhausted:
		attack_speed = 0.55 # Much slower when exhausted, guard drops
	
	await get_tree().create_timer(attack_speed).timeout
	is_attacking = false
	punch_kind = ""

func _update_boxer_pose(delta: float) -> void:
	# This is intentionally applied to the Model used by the live fight scene,
	# after movement. It gives the imported boxer visible weight, guard and punch
	# commitment even when a clip is missing from the scene AnimationTree.
	if not model:
		return
	var t = Time.get_ticks_msec() * 0.001
	var desired_shift = Vector3(0, sin(t * 2.1) * 0.018, 0)
	var desired_pitch = sin(t * 2.1) * 0.022
	var desired_roll = sin(t * 1.35) * 0.028
	if is_stepping:
		var stride = sin(t * 9.0) * 0.026
		desired_shift.y += absf(stride)
		desired_shift.z += stride * 0.55
		desired_roll += move_input.x * 0.055
	if is_attacking and punch_length > 0.0:
		punch_clock = minf(punch_length, punch_clock + delta)
		var phase = punch_clock / punch_length
		var extension = sin(phase * PI)
		if punch_kind == "jab":
			desired_shift.z += -extension * 0.16
			desired_shift.x += extension * 0.035
			desired_pitch += extension * 0.075
			desired_roll += extension * 0.055
		else: # cross: more rear-leg drive, hip turn and a longer recovery
			desired_shift.z += -extension * 0.24
			desired_shift.x += -extension * 0.075
			desired_pitch += extension * 0.11
			desired_roll -= extension * 0.18
	body_shift = body_shift.lerp(desired_shift, minf(1.0, delta * 14.0))
	body_pitch = lerpf(body_pitch, desired_pitch, minf(1.0, delta * 12.0))
	body_roll = lerpf(body_roll, desired_roll, minf(1.0, delta * 12.0))
	model.position = body_shift
	model.rotation = Vector3(body_pitch, 0.0, body_roll)

func take_damage(amount: float, is_head: bool = true) -> void:
	if is_dodging:
		print("Dodged!")
		return
		
	if is_blocking:
		amount *= 0.2
		stamina = max(0, stamina - amount * 2.0)
		stamina_changed.emit(stamina)
		if stamina <= 0:
			print("Guard broken!")
			is_blocking = false
			amount *= 5.0 # Full damage on guard break
			
	if is_head:
		health -= amount
		health_changed.emit(health)
	else:
		stamina = max(0, stamina - amount * 1.5)
		stamina_changed.emit(stamina)
		health -= amount * 0.5
		health_changed.emit(health)
	
	is_hurt = true
	if playback: playback.travel("hit")
	
	var cf = get_node_or_null("/root/CombatFeel")
	if cf: 
		cf.hitstop(0.08)
		cf.camera_shake(0.3, 0.2)
		cf.spawn_sweat(global_position + Vector3(0, 1.5, 0))
	
	await get_tree().create_timer(0.4).timeout
	is_hurt = false
