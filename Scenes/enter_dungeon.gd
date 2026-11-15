extends CanvasLayer


func _ready() -> void:
	pass


func _process(delta: float) -> void:
	pass


func _on_dunegon_hub_begin_descent() -> void:
	GameManage.quit_game()
