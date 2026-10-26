extends Panel
## Visual composition lives in the scene; input ownership lives in DrivingInput.

var finger_position: Vector2 = Vector2.ZERO
var finger_active: bool = false


func _ready() -> void:
	resized.connect(update_indicator)
	update_indicator()


func set_finger(position_on_pad: Vector2, active: bool) -> void:
	finger_position = position_on_pad
	finger_active = active
	update_indicator()


func update_indicator() -> void:
	var half_size := size * 0.5
	$Indicator.position = (
			half_size + finger_position * (half_size - Vector2(12, 12)) - Vector2(10, 10)
	)
	$Indicator.modulate = Color(1, 0.2, 0.8, 1) if finger_active else Color(0.2, 0.8, 1, 0.65)
