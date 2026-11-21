extends Node

signal clue_collected(clue_id: String)
signal item_acquired(item_id: String, amount: int)
signal puzzle_solved(puzzle_id: String)
signal noise_emitted(origin: Vector2, radius: float, source_id: String)
signal player_hidden(is_hidden: bool)
signal camera_flash_fired(origin: Vector2, look_dir: Vector2)
signal phone_defense_feedback(text: String)
signal flashlight_feedback(text: String)
