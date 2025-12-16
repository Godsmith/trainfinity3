extends CanvasLayer

class_name Gui

enum State {NONE, SELECT, TRACK, ONE_WAY_TRACK, STATION, TRAIN1, TRAIN2, LIGHT, DESTROY1, DESTROY2}

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
@onready var help_button := $VBoxContainer/HBoxContainer/HelpButton
@onready var money_label := $VBoxContainer/HBoxContainer/Money
@onready var selection_description_label := $VBoxContainer/SelectionDescription

@onready var BUTTON_FROM_STATE: Dictionary[State, Button] = {
	State.SELECT: select_button,
	State.TRACK: track_button,
	State.STATION: station_button,
	State.ONE_WAY_TRACK: one_way_track_button,
	State.TRAIN1: train_button,
	State.DESTROY1: destroy_button
	}

func _ready() -> void:
	$UpgradesMenu.close_button_clicked.connect(_upgrades_close_button_clicked)
	$Help.close_button_clicked.connect(_help_close_button_clicked)
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

func _on_help_button_toggled(toggled_on: bool) -> void:
	$Help.visible = toggled_on

func _help_close_button_clicked() -> void:
	$Help.visible = false
	help_button.set_pressed_no_signal(false)

func set_follow_train_button_visibility(visible_: bool):
	follow_train_button.visible = visible_

func show_saved_visual_feedback():
	var original_text = save_button.text
	save_button.text = "Saved!"
	save_button.disabled = true
	get_tree().create_timer(1.0).timeout.connect(func():
		save_button.text = original_text
		save_button.disabled = false
	)

func set_pressed_no_signal(state: State):
	if state in BUTTON_FROM_STATE:
		for button in BUTTON_FROM_STATE.values():
			button.set_pressed_no_signal(false)
		BUTTON_FROM_STATE[state].set_pressed_no_signal(true)
