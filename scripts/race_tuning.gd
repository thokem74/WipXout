class_name RaceTuning
extends Resource
## Gameplay values use metres, seconds and radians unless named otherwise.

@export var top_speed: float = 90.0
@export var acceleration: float = 45.0
@export var braking: float = 85.0
@export var coast_drag: float = 5.0
@export var steering_acceleration: float = 60.0
@export var lateral_damping: float = 2.7
@export var wall_speed_retention: float = 0.85
@export var boost_speed: float = 140.0
@export var boost_drain: float = 0.27
@export var boost_recharge: float = 0.14
@export var boost_cooldown: float = 1.2
@export var hover_height: float = 1.6
@export var camera_distance: float = 10.0
@export var camera_height: float = 4.2
@export var camera_response: float = 7.0

# Arcade flight remains in the track corridor, with a ballistic height above it.
@export var jump_gravity: float = 18.0
@export var minimum_jump_speed: float = 25.0
@export var maximum_launch_speed: float = 32.0
@export var air_steering_factor: float = 0.65

# Track-relative forces and bounded presentation controls.
@export var corner_drift_factor: float = 0.12
@export var camera_lookahead: float = 26.0
@export var camera_speed_fov: float = 12.0
@export var camera_boost_fov: float = 8.0
@export var takeoff_impulse: float = 0.22
@export var landing_impulse: float = 0.48
@export var maximum_camera_impulse: float = 0.55
@export var boost_flame_scale: float = 2.0
@export var boost_trail_ratio: float = 1.0
