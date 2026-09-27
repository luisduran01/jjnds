extends RefCounted
# Sistema de distancia y clinch — Corner Club

enum FightRange { LONG, MID, SHORT, CLINCH }

# Distancias umbral en metros
const LONG_THRESHOLD   := 1.55
const MID_THRESHOLD    := 1.0
const SHORT_THRESHOLD  := 0.65
const CLINCH_THRESHOLD := 0.38

# Estado del clinch
var in_clinch         := false
var clinch_timer      := 0.0
var clinch_break_time := 2.0   # Tiempo antes de que el árbitro los separe
var break_cooldown    := 0.0   # Tiempo hasta que puedan volver a clinch

signal clinch_started()
signal clinch_broken()
signal range_changed(new_range: int)

var current_range := FightRange.LONG

func classify(distance: float) -> int:
	if distance < CLINCH_THRESHOLD: return FightRange.CLINCH
	if distance < SHORT_THRESHOLD:  return FightRange.SHORT
	if distance < MID_THRESHOLD:    return FightRange.MID
	return FightRange.LONG

func update(delta: float, distance: float, player_state, enemy_state) -> void:
	break_cooldown = maxf(0.0, break_cooldown - delta)
	var new_range = classify(distance)
	if new_range != current_range:
		current_range = new_range
		range_changed.emit(new_range)

	# Clinch: sólo si los dos están en pie y atacando/moviéndose demasiado cerca
	var both_fighting = (player_state not in [6, 7, 11, 12]) and \
						(enemy_state not in [6, 7, 11, 12])
	if new_range == FightRange.CLINCH and both_fighting and break_cooldown <= 0.0:
		if not in_clinch:
			in_clinch = true
			clinch_timer = 0.0
			clinch_started.emit()
		else:
			clinch_timer += delta
	elif in_clinch:
		in_clinch = false
		clinch_timer = 0.0
		clinch_broken.emit()

func should_break_clinch() -> bool:
	return in_clinch and clinch_timer >= clinch_break_time

func on_referee_break() -> void:
	in_clinch = false
	clinch_timer = 0.0
	break_cooldown = 3.0  # 3 segundos de cooldown antes del próximo clinch

# Modificadores de daño según la distancia de cada golpe
static func punch_effectiveness(punch: String, distance: float) -> float:
	var traj = ""
	match punch:
		"jab", "cross", "body_jab", "body_cross": traj = "straight"
		"left_hook", "right_hook", "body_hook":    traj = "hook"
		"left_uppercut", "right_uppercut":         traj = "upper"

	match traj:
		"straight":
			# Jab/cross requieren distancia media-larga
			if distance < 0.45: return 0.3   # Demasiado cerca, sin espacio
			if distance < 0.7:  return 0.7
			if distance > 1.4:  return 0.6   # Demasiado lejos, roza
			return 1.0
		"hook":
			# Hooks funcionan muy bien a corta-media distancia
			if distance < 0.38: return 0.5   # Clinch, sin espacio para girar
			if distance < 0.65: return 1.15  # Distancia ideal
			if distance > 1.1:  return 0.55  # Demasiado lejos para un hook
			return 1.0
		"upper":
			# Uppercuts son de corta distancia
			if distance < 0.38: return 0.6
			if distance < 0.7:  return 1.2   # Ideal
			if distance > 0.95: return 0.4
			return 1.0
	return 1.0
