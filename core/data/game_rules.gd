extends Resource
class_name GameRules

const BUS_ANOMALIES := ["driver_mirror", "blood_coinbox", "stop_screen", "mannequin_turn", "window_hands"]

@export var walk_speed: float = 96.0
@export var sprint_speed: float = 160.0
@export var crouch_speed: float = 56.0
@export var sprint_cost: float = 20.0
@export var stamina_delay: float = 0.8
@export var stamina_recovery: float = 15.0
@export var flashlight_cost: float = 0.2
@export var flashlight_range: float = 256.0
@export var flashlight_angle: float = 60.0
@export var phone_flash_cost: float = 25.0
@export var phone_flash_charges: int = 2
@export var phone_flash_range: float = 156.0
@export var phone_flash_angle: float = 68.0
@export var phone_flash_stun: float = 2.5
@export var phone_flash_cooldown: float = 1.0
@export var enemy_search_time: float = 5.0
@export var interaction_range: float = 48.0
@export var acceleration: float = 820.0
@export var deceleration: float = 980.0
@export var aim_response: float = 22.0
@export var walk_stride: float = 38.0
@export var sprint_stride: float = 48.0
@export var crouch_stride: float = 42.0
