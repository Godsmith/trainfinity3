extends Node

class_name Bank

signal money_changed

var _asset_count: Dictionary[Global.Asset, int] = {
	Global.Asset.TRACK: 0,
	Global.Asset.STATION: 0,
	Global.Asset.TRAIN: 0
}

const _INCREASE_FACTOR := 1.5

var money := 100
var gui: Gui
var is_effects_enabled := true

func update_gui():
	gui.show_money(money)

func spend_money(cost_: int, pos: Vector2):
	money -= cost_
	if is_effects_enabled:
		# If the game is loading, we just want everything to be restored
		# silently, without any popups
		_show_popup_and_play_sound(cost_, pos)
	gui.show_money(money)
	money_changed.emit()

func _show_popup_and_play_sound(cost_: int, pos: Vector2):
	AudioManager.play(AudioManager.COIN_SPLASH, pos)
	_show_buy_popup(cost_, pos)

func earn(amount: int):
	set_money(money + amount)

func set_money(amount: int):
	self.money = amount
	gui.show_money(money)
	money_changed.emit()

func destroy(asset: Global.Asset):
	_asset_count[asset] -= 1

func _show_buy_popup(amount_spent: int, pos: Vector2):
	Global.show_popup("-$%s" % amount_spent, pos, self, Color(1.0, 0.0, 0.0, 1.0))
