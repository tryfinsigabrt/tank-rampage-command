extends Node3D

func _ready() -> void:
	SignalBus.on_player_message_next_clicked.connect(_on_player_message_next_clicked)
	SignalBus.on_player_message_requested.emit("Welcome to the Tank Rampage Command tutorial")

func _exit_tree() -> void:
	if SignalBus.on_player_message_next_clicked.is_connected(_on_player_message_next_clicked):
		SignalBus.on_player_message_next_clicked.disconnect(_on_player_message_next_clicked)

func _on_player_message_next_clicked() -> void:
	SignalBus.on_player_message_cleared.emit()
