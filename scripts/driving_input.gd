class_name DrivingInput
extends Node
## Fixed-position touchpad and independent Boost capture, plus desktop controls.

signal pad_changed(position: Vector2, active: bool)

const NO_POINTER: int = -2
const MOUSE_POINTER: int = -1
const DEAD_ZONE: float = 0.1
const DRIVING_KEYS: Array[Key] = [
	KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE,
]

var enabled: bool = false:
	set(value):
		if enabled != value:
			enabled = value
			clear()
var sensitivity: float = 1.0
var pad_rect: Rect2
var boost_rect: Rect2
var pad_pointer: int = NO_POINTER
var pad_position: Vector2 = Vector2.ZERO
var boost_touches: Dictionary = {}
var keyboard_blocked: bool = true


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			press_pointer(event.index, event.position)
		else:
			release_pointer(event.index)
	elif event is InputEventScreenDrag:
		drag_pointer(event.index, event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press_pointer(MOUSE_POINTER, event.position)
		else:
			release_pointer(MOUSE_POINTER)
	elif event is InputEventMouseMotion:
		drag_pointer(MOUSE_POINTER, event.position)


func clear() -> void:
	# Discard captures rather than recapturing fingers still held after a menu closes.
	pad_pointer = NO_POINTER
	pad_position = Vector2.ZERO
	boost_touches.clear()
	keyboard_blocked = true
	pad_changed.emit(pad_position, false)


func set_regions(driving_rect: Rect2, boosting_rect: Rect2) -> void:
	if pad_rect != driving_rect or boost_rect != boosting_rect:
		clear()
	pad_rect = driving_rect
	boost_rect = boosting_rect


func press_pointer(pointer: int, position: Vector2) -> void:
	if not enabled:
		return
	if pad_rect.has_point(position) and pad_pointer == NO_POINTER:
		pad_pointer = pointer
		update_pad(position)
	elif boost_rect.has_point(position) and pointer != pad_pointer:
		boost_touches[pointer] = true


func release_pointer(pointer: int) -> void:
	if pointer == pad_pointer:
		pad_pointer = NO_POINTER
		pad_position = Vector2.ZERO
		pad_changed.emit(pad_position, false)
	boost_touches.erase(pointer)


func drag_pointer(pointer: int, position: Vector2) -> void:
	if pointer == pad_pointer:
		# Retain the driving finger outside the pad and clamp each axis independently.
		update_pad(position)
	elif boost_touches.has(pointer) and not boost_rect.has_point(position):
		boost_touches.erase(pointer)


func update_pad(position: Vector2) -> void:
	if pad_rect.size.x <= 0 or pad_rect.size.y <= 0:
		return
	pad_position = ((position - pad_rect.get_center()) / (pad_rect.size * 0.5)).clamp(
			Vector2(-1, -1), Vector2(1, 1)
	)
	pad_changed.emit(pad_position, true)


func axis_value(value: float) -> float:
	return signf(value) * clampf((absf(value) - DEAD_ZONE) / (1.0 - DEAD_ZONE), 0, 1)


func read_controls(_delta: float) -> Vector3:
	if not enabled:
		return Vector3.ZERO
	if keyboard_blocked:
		var held := false
		for key: Key in DRIVING_KEYS:
			held = held or Input.is_physical_key_pressed(key)
		keyboard_blocked = held
	var keyboard := Vector3.ZERO
	if not keyboard_blocked:
		keyboard.x = (
				float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
				- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		)
		keyboard.y = (
				float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
				- float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		)
		keyboard.z = float(Input.is_physical_key_pressed(KEY_SPACE))
	var steering := keyboard.x
	var throttle := keyboard.y
	if pad_pointer != NO_POINTER:
		steering = clampf(axis_value(pad_position.x) * sensitivity, -1, 1)
		throttle = axis_value(-pad_position.y)
	return Vector3(steering, throttle, 1.0 if not boost_touches.is_empty() else keyboard.z)
