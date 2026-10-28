extends Node

## Daily login rewards with 7-day streak.

signal daily_reward_available(day: int, amount: float)

const REWARDS := [100.0, 200.0, 300.0, 400.0, 500.0, 750.0, 1000.0]


func _ready() -> void:
	call_deferred("_check_login")


func _check_login() -> void:
	var today := Time.get_date_string_from_system()
	if GameState.last_login_date == today:
		return
	# Determine streak
	if GameState.last_login_date == "":
		GameState.daily_streak = 1
	else:
		var last := GameState.last_login_date
		# simple: if last date is yesterday keep streak else reset
		if _is_yesterday(last, today):
			GameState.daily_streak += 1
		else:
			GameState.daily_streak = 1
	if GameState.daily_streak > 7:
		GameState.daily_streak = 1
	GameState.last_login_date = today
	var day_index := GameState.daily_streak - 1
	var amount: float = REWARDS[day_index] if day_index < REWARDS.size() else REWARDS[-1]
	if GameState.daily_claimed_date != today:
		daily_reward_available.emit(GameState.daily_streak, amount)


func claim() -> void:
	var today := Time.get_date_string_from_system()
	var amount := get_reward_amount(GameState.daily_streak)
	GameState.add_cash(amount)
	GameState.daily_claimed_date = today
	SaveManager.save()


func get_reward_amount(day: int) -> float:
	if REWARDS.is_empty():
		return 0.0
	var index := clampi(day - 1, 0, REWARDS.size() - 1)
	return float(REWARDS[index])


func _is_yesterday(last: String, today: String) -> bool:
	# Compare by parsing date strings (YYYY-MM-DD).
	var last_parts := last.split("-")
	var today_parts := today.split("-")
	if last_parts.size() != 3 or today_parts.size() != 3:
		return false
	# Convert to unix day approximation
	var last_days := int(last_parts[0]) * 365 + int(last_parts[1]) * 30 + int(last_parts[2])
	var today_days := int(today_parts[0]) * 365 + int(today_parts[1]) * 30 + int(today_parts[2])
	return today_days - last_days == 1