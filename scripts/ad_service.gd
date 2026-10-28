extends Node

## Stub ad service: rewarded ads grant reward immediately.

signal rewarded_granted

func show_rewarded_ad() -> void:
	# Stub: grant reward immediately.
	rewarded_granted.emit()