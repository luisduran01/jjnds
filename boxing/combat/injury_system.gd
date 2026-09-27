extends RefCounted
# Sistema de lesiones — Corner Club
# Cada lesión tiene nivel 0-3. Nivel 3 puede provocar TKO médico.

const INJURY_NONE   = 0
const INJURY_MINOR  = 1
const INJURY_MODERATE = 2
const INJURY_SEVERE = 3

# Tipos de lesión
var eye_cut_left   := 0   # Corte ceja izquierda
var eye_cut_right  := 0   # Corte ceja derecha
var nose_damage    := 0   # Nariz rota
var eye_swollen    := 0   # Ojo hinchado (visión parcial)
var body_punishment:= 0   # Cuerpo castigado

# Acumuladores de daño por zona
var accumulated_head_left  := 0.0
var accumulated_head_right := 0.0
var accumulated_nose       := 0.0
var accumulated_body       := 0.0
var accumulated_eye_left   := 0.0

# Historial por round para la esquina
var round_stats := []

signal injury_updated(type, level)
signal medical_stoppage_risk()

func reset_round_stats() -> void:
	round_stats.append({
		"eye_cut_left": eye_cut_left,
		"eye_cut_right": eye_cut_right,
		"nose": nose_damage,
		"eye_swollen": eye_swollen,
		"body": body_punishment
	})

func receive_damage(zone: String, punch_type: String, amount: float, local_pos: Vector3) -> void:
	match zone:
		"head":
			# Distinguir lado del impacto con la posición local
			if local_pos.x < -0.05:  # Lado izquierdo del luchador = impacto derecho del rival
				accumulated_head_left += amount
				accumulated_eye_left  += amount * 0.6
				_update_cut(amount, "left")
				_update_eye(amount)
			else:
				accumulated_head_right += amount
				accumulated_nose += amount * 0.4
				_update_cut(amount, "right")
				_update_nose(amount)
		"body":
			accumulated_body += amount
			_update_body(amount)

func _update_cut(amount: float, side: String) -> void:
	var threshold = [0, 28, 55, 90]
	var prev = eye_cut_left if side == "left" else eye_cut_right
	var acc  = accumulated_head_left if side == "left" else accumulated_head_right
	var new_level = 0
	for i in range(3, 0, -1):
		if acc >= threshold[i]:
			new_level = i
			break
	if side == "left":
		eye_cut_left = new_level
	else:
		eye_cut_right = new_level
	if new_level > prev:
		injury_updated.emit("cut_" + side, new_level)
		if new_level >= INJURY_SEVERE:
			medical_stoppage_risk.emit()

func _update_nose(amount: float) -> void:
	var prev = nose_damage
	if accumulated_nose >= 70: nose_damage = INJURY_SEVERE
	elif accumulated_nose >= 42: nose_damage = INJURY_MODERATE
	elif accumulated_nose >= 20: nose_damage = INJURY_MINOR
	if nose_damage > prev:
		injury_updated.emit("nose", nose_damage)

func _update_eye(amount: float) -> void:
	var prev = eye_swollen
	if accumulated_eye_left >= 60: eye_swollen = INJURY_SEVERE
	elif accumulated_eye_left >= 35: eye_swollen = INJURY_MODERATE
	elif accumulated_eye_left >= 15: eye_swollen = INJURY_MINOR
	if eye_swollen > prev:
		injury_updated.emit("eye_swollen", eye_swollen)
		if eye_swollen >= INJURY_SEVERE:
			medical_stoppage_risk.emit()

func _update_body(amount: float) -> void:
	var prev = body_punishment
	if accumulated_body >= 120: body_punishment = INJURY_SEVERE
	elif accumulated_body >= 70: body_punishment = INJURY_MODERATE
	elif accumulated_body >= 30: body_punishment = INJURY_MINOR
	if body_punishment > prev:
		injury_updated.emit("body", body_punishment)

func has_medical_risk() -> bool:
	return eye_cut_left >= INJURY_SEVERE or eye_cut_right >= INJURY_SEVERE or eye_swollen >= INJURY_SEVERE

func corner_treat(treatment: String) -> Dictionary:
	# Tratamientos entre rounds que la esquina puede aplicar
	match treatment:
		"reduce_swelling":
			eye_swollen = maxi(0, eye_swollen - 1)
			accumulated_eye_left *= 0.6
			return {"stamina_bonus": 0.0, "health_bonus": 2.0, "msg": "Hinchazón reducida"}
		"treat_cut":
			eye_cut_left = maxi(0, eye_cut_left - 1)
			eye_cut_right = maxi(0, eye_cut_right - 1)
			accumulated_head_left *= 0.5
			accumulated_head_right *= 0.5
			return {"stamina_bonus": 0.0, "health_bonus": 1.0, "msg": "Corte tratado"}
		"recover_stamina":
			return {"stamina_bonus": 25.0, "health_bonus": 0.0, "msg": "Stamina recuperada"}
		"change_strategy":
			return {"stamina_bonus": 5.0, "health_bonus": 3.0, "msg": "Estrategia ajustada"}
	return {"stamina_bonus": 0.0, "health_bonus": 0.0, "msg": ""}

func injury_labels() -> Array:
	var labels = []
	if eye_cut_left >= INJURY_MINOR:
		labels.append(["✂ Corte ceja izq", ["", "leve", "moderado", "grave"][eye_cut_left]])
	if eye_cut_right >= INJURY_MINOR:
		labels.append(["✂ Corte ceja der", ["", "leve", "moderado", "grave"][eye_cut_right]])
	if nose_damage >= INJURY_MINOR:
		labels.append(["👃 Nariz", ["", "golpeada", "rota", "muy dañada"][nose_damage]])
	if eye_swollen >= INJURY_MINOR:
		labels.append(["👁 Ojo", ["", "hinchado", "cerrado parcial", "casi cerrado"][eye_swollen]])
	if body_punishment >= INJURY_MINOR:
		labels.append(["🩻 Cuerpo", ["", "castigado", "muy castigado", "crítico"][body_punishment]])
	return labels
