extends Node

class_name Bank

const _start_price := {
    Global.Asset.TRACK: 1.0,
    Global.Asset.STATION: 10.0,
    Global.Asset.TRAIN: 20.0
}
var _current_price: Dictionary[Global.Asset, float] = {
    Global.Asset.TRACK: _start_price[Global.Asset.TRACK],
    Global.Asset.STATION: 0.0,
    Global.Asset.TRAIN: 0.0
}

var _asset_count: Dictionary[Global.Asset, int] = {
    Global.Asset.TRACK: 0,
    Global.Asset.STATION: 0,
    Global.Asset.TRAIN: 0
}

var _free_asset_count: Dictionary[Global.Asset, int] = {
    Global.Asset.TRACK: 0,
    Global.Asset.STATION: 2,
    Global.Asset.TRAIN: 1
}

const _INCREASE_FACTOR := 1.5

var money := 30
var gui: Gui

func _init(gui_: Gui):
    gui = gui_
    gui.update_prices(_current_price)
    gui.show_money(money)


func cost(asset: Global.Asset, amount := 1) -> int:
    return amount * floori(_current_price[asset])

func can_afford(asset: Global.Asset, amount := 1) -> bool:
    return cost(asset, amount) <= money

func buy(asset: Global.Asset, amount := 1):
    money -= cost(asset, amount)
    _asset_count[asset] += amount
    self._update_prices()
    gui.show_money(money)

func _update_prices():
    for asset in Global.Asset.values():
        if asset == Global.Asset.TRACK:
            _current_price[asset] = _start_price[asset] * (1 + _asset_count[asset] / 10)
        else:
            if _asset_count[asset] < _free_asset_count[asset]:
                _current_price[asset] = 0.0
            else:
                _current_price[asset] = _start_price[asset] * _INCREASE_FACTOR ** _asset_count[asset]
    gui.update_prices(_current_price)

func earn(amount: int):
    self.money += amount
    gui.show_money(money)

func destroy(asset: Global.Asset):
    _asset_count[asset] -= 1
    self._update_prices()
