extends Resource
class_name GameData

@export var game_name: String = ""
@export var thumbnail: Texture2D
@export var field_scene: PackedScene
@export var scoring_scene: PackedScene
@export var ui_scene: PackedScene
@export var game_pieces: Array[String] = []

@export var autonomous_time: float = 15.0
@export var teleop_time: float = 135.0
@export var endgame_time: float = 30.0

@export var point_values: Dictionary = {}
