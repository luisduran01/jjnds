extends Node

# =============================================================
# ROUND MANAGER — Phase 4 Polish
# =============================================================

signal round_started(round_number: int)
signal round_ended(round_number: int)
signal fight_ended_by_decision
signal time_updated(time_left: float)
signal rest_time_updated(time_left: float)

@export var max_rounds: int = 3
@export var round_duration: float = 60.0
@export var rest_duration: float = 10.0

var current_round: int = 1
var time_left: float = 0.0
var is_fighting: bool = false
var is_resting: bool = false
var is_paused: bool = false

func start_fight() -> void:
	current_round = 1
	is_paused = false
	start_round()

func start_round() -> void:
	is_resting = false
	is_fighting = true
	is_paused = false
	time_left = round_duration
	round_started.emit(current_round)

func end_round() -> void:
	is_fighting = false
	is_resting = true
	is_paused = false
	time_left = rest_duration
	round_ended.emit(current_round)

	if current_round >= max_rounds:
		is_resting = false
		fight_ended_by_decision.emit()
	else:
		current_round += 1

func stop_fight_immediately() -> void:
	# Used when KO or TKO occurs — stops timer dead.
	is_fighting = false
	is_resting = false
	is_paused = false

func pause_timer() -> void:
	is_paused = true

func resume_timer() -> void:
	is_paused = false

func _process(delta: float) -> void:
	if is_paused:
		return

	if is_fighting:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			end_round()
		time_updated.emit(time_left)
	elif is_resting:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			start_round()
		rest_time_updated.emit(time_left)
