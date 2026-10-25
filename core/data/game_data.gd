class_name GameData
extends RefCounted
## 資料載入(靜態快取):data/config/game.json(數值)、data/items.json(物品外觀)、data/stations.json(工作站)、
## data/counters.json(櫃台)、data/shop.json(價格牌)。改資料不用動程式。

const CONFIG_PATH := "res://data/config/game.json"
const ITEMS_PATH := "res://data/items.json"
const STATIONS_PATH := "res://data/stations.json"
const COUNTERS_PATH := "res://data/counters.json"
const SHOP_PATH := "res://data/shop.json"

static var _config := {}
static var _items := {}
static var _stations := {}
static var _counters := {}
static var _shop: Array = []
static var _loaded := false


static func reload() -> void:
    _config = _load(CONFIG_PATH)
    _items = {}
    var items = _load(ITEMS_PATH).get("items", {})
    if typeof(items) == TYPE_DICTIONARY:
        for id in items:
            _items[str(id)] = items[id]
    _stations = _index(_load(STATIONS_PATH).get("stations", []))
    _counters = _index(_load(COUNTERS_PATH).get("counters", []))
    _shop = []
    var shop = _load(SHOP_PATH).get("purchases", [])
    if typeof(shop) == TYPE_ARRAY:
        for p in shop:
            if typeof(p) == TYPE_DICTIONARY and p.has("id"):
                _shop.append(p)
    _loaded = true


static func _index(raw) -> Dictionary:
    var out := {}
    if typeof(raw) == TYPE_ARRAY:
        for e in raw:
            if typeof(e) == TYPE_DICTIONARY and e.has("id"):
                out[str(e["id"])] = e
    return out


static func _load(path: String) -> Dictionary:
    var text := FileAccess.get_file_as_string(path)
    var parsed = JSON.parse_string(text) if text != "" else null
    if typeof(parsed) != TYPE_DICTIONARY:
        push_warning("資料讀取失敗:%s" % path)
        return {}
    return parsed


static func _ensure() -> void:
    if not _loaded:
        reload()


static func config() -> Dictionary:
    _ensure()
    return _config


## config 的子區塊(例如 "fish"、"customers"、"helpers"),沒有就空字典
static func section(key: String) -> Dictionary:
    var v = config().get(key, {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


## 幫手角色設定(helpers.<role>)
static func helper(role: String) -> Dictionary:
    var v = section("helpers").get(role, {})
    return v if typeof(v) == TYPE_DICTIONARY else {}


static func items() -> Dictionary:
    _ensure()
    return _items


static func item(id: String) -> Dictionary:
    _ensure()
    return _items.get(id, {})


static func item_size(id: String) -> Vector3:
    var s = item(id).get("size", null)
    if typeof(s) == TYPE_ARRAY and s.size() >= 3:
        return Vector3(float(s[0]), float(s[1]), float(s[2]))
    return Vector3(0.5, 0.15, 0.4)


static func item_color(id: String) -> Color:
    var c := str(item(id).get("color", ""))
    return Color.html(c) if Color.html_is_valid(c) else Color(0.8, 0.8, 0.8)


## 物品顯示名(翻譯鍵 ITEM_<id>,資料可用 name 覆寫)
static func item_name(id: String) -> String:
    var key := str(item(id).get("name", "ITEM_%s" % id))
    var t := str(TranslationServer.translate(key))
    return id if t == key else t


static func stations() -> Array:
    _ensure()
    return _stations.values()


static func station(id: String) -> Dictionary:
    _ensure()
    return _stations.get(id, {})


static func counters() -> Array:
    _ensure()
    return _counters.values()


static func counter(id: String) -> Dictionary:
    _ensure()
    return _counters.get(id, {})


static func shop() -> Array:
    _ensure()
    return _shop


static func purchase(id: String) -> Dictionary:
    for p in shop():
        if str(p.get("id", "")) == id:
            return p
    return {}
