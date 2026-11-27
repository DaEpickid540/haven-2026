extends "res://Scripts/dungeon_room.gd"

# doorway
const DOOR_CELLS: Array[Vector2i] = [
	Vector2i(-16, -23), Vector2i(-15, -23), Vector2i(-14, -23), Vector2i(-13, -23), Vector2i(-12, -23),
]
const DOOR_TILES: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(4, 4), Vector2i(4, 4), Vector2i(4, 4), Vector2i(4, 4),
]
const DOOR_SOURCE := 0
# inside
const SLAM_Y := -376.0
const SLAM_SHAKE := 0.8

var _slammed := false


func _physics_process(_delta: float) -> void:
	if _slammed or $Player.position.y > SLAM_Y:
		return
	_slam()


func _slam() -> void:
	_slammed = true
	var layer: TileMapLayer = $Dungeon
	for i in DOOR_CELLS.size():
		layer.set_cell(DOOR_CELLS[i], DOOR_SOURCE, DOOR_TILES[i])
	Juice.shake(SLAM_SHAKE)
	Audio.play_sfx("hit")
	RoomBanner.show_name("Boss Slime")
	$BossGreen.wake()
