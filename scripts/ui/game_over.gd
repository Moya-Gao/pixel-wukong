## Game Over UI
extends Control

@onready var restart_button: Button = $VBox/RestartButton

var _can_restart = true

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    restart_button.pressed.connect(_on_restart_pressed)
    get_tree().paused = true

func _on_restart_pressed() -> void:
    if not _can_restart or restart_button == null:
        return
    _can_restart = false
    get_tree().paused = false
    get_tree().reload_current_scene()