extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state := root.get_node("GameState")
	if state.profile != "test" or not state.opening_checkpoint_enabled():
		quit(2)
		return
	if "--write-phone" in OS.get_cmdline_user_args():
		state.reset_opening()
		state.phone_battery = 31.0
		state.phone_flash_charges = 1
		state.phone_flash_cooldown = 0.73
		state.phone_supplied_chapters = {"ch0_tanglau":true}
		state.set_reduced_flash(true)
		if not state.save_opening_checkpoint():
			quit(1)
			return
		print("PASS phone state and visual preference persisted in isolated write process")
	else:
		state.prepare_opening_resume()
		var valid: bool = state.phone_battery == 31.0 and state.phone_flash_charges == 1 and is_equal_approx(state.phone_flash_cooldown, 0.73) and state.phone_supplied_chapters == {"ch0_tanglau":true} and state.reduced_flash
		print(("PASS " if valid else "FAIL ") + "fresh process restores spent resources, cooldown, supply ledger and independent preference")
		if not valid:
			quit(1)
			return
	quit(0)
