class_name RaceTuning
extends Resource
## Gameplay values use metres, seconds and radians unless named otherwise.

@export var top_speed: float = 88.0
@export var acceleration: float = 32.0
@export var braking: float = 65.0
@export var coast_drag: float = 5.0
@export var steering_acceleration: float = 34.0
@export var lateral_damping: float = 2.7
@export var wall_speed_retention: float = 0.80
@export var boost_speed: float = 116.0
@export var boost_drain: float = 0.27
@export var boost_recharge: float = 0.14
@export var boost_cooldown: float = 1.2
@export var hover_height: float = 1.6
@export var camera_distance: float = 10.0
@export var camera_height: float = 4.2
@export var camera_response: float = 7.0

# Arcade flight remains in the track corridor, with a ballistic height above it.
@export var jump_gravity: float = 16.0
@export var minimum_jump_speed: float = 25.0
@export var maximum_launch_speed: float = 17.6
@export var air_steering_factor: float = 0.5
