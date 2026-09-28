extends RefCounted
# Sistema de momentum y estadísticas de pelea — Corner Club

var momentum := 0.0          # -1.0 (rival domina) a +1.0 (jugador domina)
var composure_player := 1.0  # 0.0 = sin compostura, 1.0 = compuesto
var composure_enemy  := 1.0

# Estadísticas por round (se acumulan)
var stats_player := _empty_stats()
var stats_enemy  := _empty_stats()
var round_history_player: Array = []
var round_history_enemy:  Array = []

# Consecutivos para momentum
var consecutive_clean_player := 0
var consecutive_clean_enemy  := 0

signal momentum_shift(value: float, who: String)
signal composure_lost(who: String)

func _empty_stats() -> Dictionary:
	return {
		"thrown": 0, "connected": 0, "clean": 0,
		"head": 0, "body": 0, "counters": 0,
		"knockdowns": 0, "damage": 0.0
	}

func reset_round() -> void:
	round_history_player.append(stats_player.duplicate())
	round_history_enemy.append(stats_enemy.duplicate())
	stats_player = _empty_stats()
	stats_enemy  = _empty_stats()
	consecutive_clean_player = 0
	consecutive_clean_enemy  = 0

func record_throw(is_player: bool) -> void:
	if is_player: stats_player["thrown"] += 1
	else:         stats_enemy["thrown"] += 1

func record_hit(is_attacker_player: bool, info: Dictionary) -> void:
	var atk = stats_player if is_attacker_player else stats_enemy
	atk["connected"] += 1
	if info.get("zone", "") == "head": atk["head"] += 1
	else:                              atk["body"] += 1
	if info.get("counter", false):     atk["counters"] += 1
	atk["damage"] += info.get("damage", 0.0)

	var clean = not info.get("blocked", false) and info.get("accuracy", 1.0) > 0.75
	if clean: atk["clean"] += 1

	# Momentum
	_update_momentum(is_attacker_player, info, clean)

func record_knockdown(is_player_down: bool) -> void:
	if is_player_down: stats_enemy["knockdowns"] += 1
	else:              stats_player["knockdowns"] += 1
	# Gran swing de momentum
	var shift = 0.45 if not is_player_down else -0.45
	momentum = clampf(momentum + shift, -1.0, 1.0)
	momentum_shift.emit(momentum, "knockdown")

func _update_momentum(attacker_is_player: bool, info: Dictionary, clean: bool) -> void:
	var dmg    = info.get("damage", 0.0)
	var shift  = clampf(dmg / 22.0, 0.02, 0.12)
	if info.get("blocked", false): shift *= 0.3
	if info.get("counter", false): shift *= 1.6
	if attacker_is_player: momentum += shift
	else:                  momentum -= shift
	momentum = clampf(momentum, -1.0, 1.0)

	# Consecutivos limpios
	if clean:
		if attacker_is_player:
			consecutive_clean_player += 1
			consecutive_clean_enemy   = 0
			if consecutive_clean_player >= 3:
				composure_enemy = maxf(0.35, composure_enemy - 0.18)
				if composure_enemy < 0.5:
					composure_lost.emit("enemy")
		else:
			consecutive_clean_enemy += 1
			consecutive_clean_player = 0
			if consecutive_clean_enemy >= 3:
				composure_player = maxf(0.35, composure_player - 0.18)
				if composure_player < 0.5:
					composure_lost.emit("player")
	# Una contra limpia restaura compostura
	if info.get("counter", false) and clean:
		if attacker_is_player:
			composure_player = minf(1.0, composure_player + 0.25)
			composure_enemy  = maxf(0.5, composure_enemy)
		else:
			composure_enemy  = minf(1.0, composure_enemy + 0.25)
			composure_player = maxf(0.5, composure_player)
	momentum_shift.emit(momentum, "player" if attacker_is_player else "enemy")

# Recuperación de compostura por tiempo
func tick(delta: float) -> void:
	composure_player = minf(1.0, composure_player + delta * 0.08)
	composure_enemy  = minf(1.0, composure_enemy  + delta * 0.08)

# Compostura afecta precisión y reacción defensiva
func composure_accuracy_modifier(is_player: bool) -> float:
	var c = composure_player if is_player else composure_enemy
	return lerpf(0.65, 1.0, c)

func composure_defense_modifier(is_player: bool) -> float:
	var c = composure_player if is_player else composure_enemy
	return lerpf(0.5, 1.0, c)

func precision(is_player: bool) -> float:
	var s = stats_player if is_player else stats_enemy
	if s["thrown"] == 0: return 0.0
	return float(s["connected"]) / float(s["thrown"])

func total_stats(is_player: bool) -> Dictionary:
	var hist = round_history_player if is_player else round_history_enemy
	var cur  = stats_player if is_player else stats_enemy
	var total = _empty_stats()
	for r in hist:
		for k in total: total[k] += r[k]
	for k in total: total[k] += cur[k]
	return total
