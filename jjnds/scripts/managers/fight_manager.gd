extends Node

class_name FightManager

# =============================================================
# FIGHT MANAGER — Phase 4 Polish
# =============================================================

signal fight_finished(winner: String, method: String)

var player_score: int = 0
var enemy_score: int = 0

var p_punches_thrown: int = 0
var p_punches_landed: int = 0
var p_knockdowns: int = 0
var p_round_score: int = 10

var e_punches_thrown: int = 0
var e_punches_landed: int = 0
var e_knockdowns: int = 0
var e_round_score: int = 10

var fight_over: bool = false

# Max knockdowns before TKO
const MAX_KNOCKDOWNS: int = 3

func start_fight() -> void:
	fight_over = false
	player_score = 0
	enemy_score = 0
	_reset_round_stats()

func _reset_round_stats() -> void:
	p_punches_thrown = 0
	p_punches_landed = 0
	p_knockdowns = 0
	p_round_score = 10

	e_punches_thrown = 0
	e_punches_landed = 0
	e_knockdowns = 0
	e_round_score = 10

func record_punch_thrown(is_player: bool) -> void:
	if fight_over: return
	if is_player:
		p_punches_thrown += 1
	else:
		e_punches_thrown += 1

func record_punch_landed(is_player: bool) -> void:
	if fight_over: return
	if is_player:
		p_punches_landed += 1
	else:
		e_punches_landed += 1

func record_knockdown(victim_is_player: bool) -> void:
	if fight_over: return
	if victim_is_player:
		p_knockdowns += 1
		p_round_score = max(p_round_score - 1, 7)
		if p_knockdowns >= MAX_KNOCKDOWNS:
			_stop_timer()
			declare_winner("Enemy", "TKO (3 Knockdowns)")
	else:
		e_knockdowns += 1
		e_round_score = max(e_round_score - 1, 7)
		if e_knockdowns >= MAX_KNOCKDOWNS:
			_stop_timer()
			declare_winner("Player", "TKO (3 Knockdowns)")

func _stop_timer() -> void:
	var rm = Engine.get_main_loop().root.get_node_or_null("RoundManager")
	if rm and rm.has_method("stop_fight_immediately"):
		rm.stop_fight_immediately()

func score_round_end() -> void:
	var p_score = p_round_score
	var e_score = e_round_score

	# Landed punches break ties
	if p_score == e_score:
		if p_punches_landed > e_punches_landed + 3:
			e_score = max(e_score - 1, 7)
		elif e_punches_landed > p_punches_landed + 3:
			p_score = max(p_score - 1, 7)

	player_score += p_score
	enemy_score += e_score

	_reset_round_stats()

func declare_winner(winner_name: String, method: String) -> void:
	if fight_over: return
	fight_over = true
	fight_finished.emit(winner_name, method)

func evaluate_decision() -> void:
	score_round_end()
	if player_score > enemy_score:
		declare_winner("Player", "Unanimous Decision")
	elif enemy_score > player_score:
		declare_winner("Enemy", "Unanimous Decision")
	else:
		declare_winner("Draw", "Draw")
