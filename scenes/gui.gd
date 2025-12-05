extends CanvasLayer

class_name Gui

enum State {NONE, SELECT, TRACK1, TRACK2, ONE_WAY_TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY1, DESTROY2}

@onready var follow_train_button := $VBoxContainer/FollowTrainButton
@onready var select_button := $VBoxContainer/HBoxContainer/SelectButton
@onready var track_button := $VBoxContainer/HBoxContainer/TrackButton
@onready var station_button := $VBoxContainer/HBoxContainer/StationButton
@onready var train_button := $VBoxContainer/HBoxContainer/TrainButton
@onready var one_way_track_button := $VBoxContainer/HBoxContainer/OneWayTrackButton
@onready var light_button := $VBoxContainer/HBoxContainer/LightButton
@onready var destroy_button := $VBoxContainer/HBoxContainer/DestroyButton
@onready var save_button := $VBoxContainer/HBoxContainer/SaveButton
@onready var upgrades_button := $VBoxContainer/HBoxContainer/UpgradesButton
@onready var money_label := $VBoxContainer/HBoxContainer/Money
@onready var selection_description_label := $VBoxContainer/SelectionDescription

func _ready() -> void:
	$UpgradesMenu.close_button_clicked.connect(_upgrades_close_button_clicked)
	selection_description_label.text = ""
	follow_train_button.visible = false

func show_money(money: int):
	money_label.text = "$%s" % money

func update_prices(prices: Dictionary[Global.Asset, float]):
	track_button.text = "Track $%s" % floori(prices[Global.Asset.TRACK])
	station_button.text = "Station $%s" % floori(prices[Global.Asset.STATION])
	train_button.text = "Train $%s" % floori(prices[Global.Asset.TRAIN])

func _on_upgrades_button_toggled(toggled_on: bool) -> void:
	$UpgradesMenu.visible = toggled_on

func _upgrades_close_button_clicked() -> void:
	$UpgradesMenu.visible = false
	upgrades_button.set_pressed_no_signal(false)

func set_follow_train_button_visibility(visible_: bool):
	follow_train_button.visible = visible_
