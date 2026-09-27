extends RefCounted
class_name CombatStateMachine

signal transitioned(previous: int, next: int, reason: StringName)
signal buffer_expired(action: Dictionary)

enum State { IDLE, MOVING, ATTACKING, BLOCKING, DODGING, HURT, STUNNED, KNOCKDOWN, GET_UP, KO, VICTORY, DEFEAT }

const PRIORITY := {
	State.IDLE: 0,
	State.MOVING: 1,
	State.ATTACKING: 2,
	State.BLOCKING: 2,
	State.DODGING: 2,
	State.HURT: 3,
	State.STUNNED: 4,
	State.KNOCKDOWN: 5,
	State.GET_UP: 5,
	State.KO: 6,
	State.VICTORY: 6,
	State.DEFEAT: 6,
}

var state: int = State.IDLE
var remaining := 0.0
var reason: StringName = &""
var _timed := false
var _buffered: Dictionary = {}
var _buffer_life := 0.0

func request(next: int, duration: float, next_reason: StringName = &"") -> bool:
	if not PRIORITY.has(next):
		return false
	if state == State.KO and next != State.KO:
		return false
	if next != State.IDLE and remaining > 0.0 and PRIORITY[next] < PRIORITY[state]:
		return false
	_transition(next, maxf(0.0, duration), next_reason)
	return true

func tick(delta: float) -> void:
	var safe_delta := maxf(0.0, delta)
	if _buffer_life > 0.0:
		_buffer_life = maxf(0.0, _buffer_life - safe_delta)
		if _buffer_life == 0.0 and not _buffered.is_empty():
			var expired := _buffered
			_buffered = {}
			buffer_expired.emit(expired)
	if _timed:
		remaining = maxf(0.0, remaining - safe_delta)
		if remaining == 0.0:
			_transition(State.IDLE, 0.0, &"recovered")

func buffer(action: Dictionary, lifetime: float = 0.16) -> bool:
	if action.is_empty() or not _buffered.is_empty():
		return false
	_buffered = action.duplicate(true)
	_buffer_life = maxf(0.0, lifetime)
	if _buffer_life == 0.0:
		_buffered = {}
		return false
	return true

func take_buffered() -> Dictionary:
	var action := _buffered
	_buffered = {}
	_buffer_life = 0.0
	return action

func interrupt(interrupt_reason: StringName) -> void:
	if state != State.KO:
		_transition(State.IDLE, 0.0, interrupt_reason)

func reset() -> void:
	state = State.IDLE
	remaining = 0.0
	reason = &""
	_timed = false
	_buffered = {}
	_buffer_life = 0.0

func _transition(next: int, duration: float, next_reason: StringName) -> void:
	var previous := state
	state = next
	remaining = duration
	reason = next_reason
	_timed = duration > 0.0
	transitioned.emit(previous, next, next_reason)
