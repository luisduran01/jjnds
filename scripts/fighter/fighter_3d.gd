extends CharacterBody3D

@export var is_player: bool = true
var target: CharacterBody3D

var health: float = 100.0
var stamina: float = 100.0
var max_stamina: float = 100.0

@onready var anim_tree = $AnimationTree
@onready var playback = anim_tree.get("parameters/playback") if anim_tree else null

var is_attacking: bool = false
var is_blocking: bool = false
var is_hurt: bool = false

var move_speed: float = 2.5
var rotation_speed: float = 10.0

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

func _physics_process(delta: float) -> void:
	if is_hurt: return
	
	_handle_movement(delta)
	_handle_rotation(delta)
	
	if is_player:
		_handle_input()
	else:
		_handle_ai(delta)
		
	# Basic gravity
	if not is_on_floor():
		velocity.y -= 9.8 * delta
		
	move_and_slide()

func _handle_movement(delta: float) -> void:
	if is_attacking:
		velocity.x = 0
		velocity.z = 0
		return
		
	var input_dir = Vector2.ZERO
	if is_player:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed
		if playback: playback.travel("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)
		velocity.z = move_toward(velocity.z, 0, move_speed)
		if playback and not is_attacking and not is_blocking: 
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
	if is_attacking or is_blocking: return
	
	if Input.is_action_just_pressed("ui_accept"):
		punch("jab")

func _handle_ai(delta: float) -> void:
	pass # AI logic placeholder

func punch(type: String) -> void:
	if stamina < 10: return
	is_attacking = true
	stamina -= 10
	stamina_changed.emit(stamina)
	
	if playback:
		playback.travel(type)
	
	await get_tree().create_timer(0.4).timeout
	is_attacking = false

func take_damage(amount: float) -> void:
	if is_blocking:
		amount *= 0.2
	health -= amount
	health_changed.emit(health)
	
	is_hurt = true
	if playback: playback.travel("hit")
	
	var cf = get_node_or_null("/root/CombatFeel")
	if cf: cf.hitstop(0.05)
	
	await get_tree().create_timer(0.4).timeout
	is_hurt = false
