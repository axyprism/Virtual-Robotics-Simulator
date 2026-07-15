extends VBoxContainer

@onready var icon: TextureRect   = $PreviewPanel
@onready var select_button: Button = $SelectButton

var game_data: GameData

signal selected(game: GameData)

func setup(data: GameData) -> void:
	game_data = data
	icon.texture = data.thumbnail
	select_button.text = data.game_name

func _ready() -> void:
	select_button.pressed.connect(_on_select_pressed)

func _on_select_pressed() -> void:
	selected.emit(game_data)
