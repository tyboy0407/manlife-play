class_name Harbor
extends Node3D
## 星港漁市原型關卡:雪地 + 沙灘 + 淺水區(抓魚)+ 魚欄裝飾、切魚台、櫃台與排隊顧客、錢格、價格牌(shop.json),
## 玩家、跟隨相機、HUD。全部用程式碼擺放(座標在這裡,規則與數值在 data/)。
## 世界座標:x 右、-z 螢幕上(水在上面)、+z 螢幕下(顧客從右下來)。

const STATION_SPOTS := {"station_1": Vector3(-3.0, 0, 0), "station_2": Vector3(3.0, 0, 0)}
const PAD_SPOTS := {"hire_fisher": Vector3(0.0, 0, 4.5), "capacity_1": Vector3(-6.0, 0, 4.5), "expand_table": Vector3(3.0, 0, 0)}
const HELPER_SPAWN := Vector3(0.0, 0, -3.0)
const PLAYER_SPAWN := Vector3(0.0, 0, 6.5)
const HUD_SCRIPT := preload("res://game/ui/hud.gd")

var player: Player
var fish_area: FishArea
var stations: Array[Station] = []
var counter: Counter
var money_pad: MoneyPad
var price_pads := {}
var helpers: Array[Helper] = []
var camera: FollowCamera
var hud: CanvasLayer
var world: Node3D


func _ready() -> void:
    world = Node3D.new()
    world.name = "World"
    add_child(world)
    _build_environment()
    _build_terrain()
    fish_area = FishArea.new()
    fish_area.name = "FishArea"
    fish_area.rect = Rect2(-8.0, -11.0, 16.0, 7.0)
    world.add_child(fish_area)
    _build_pen_decoration()
    _add_station("station_1")
    money_pad = MoneyPad.new()
    money_pad.name = "MoneyPad"
    money_pad.position = Vector3(-5.5, 0, 8.0)
    world.add_child(money_pad)
    counter = Counter.new()
    counter.name = "Counter"
    counter.position = Vector3(3.5, 0, 7.5)
    counter.money_pad = money_pad
    world.add_child(counter)
    for def in GameData.shop():
        var id := str(def["id"])
        var pad := PricePad.create(def)
        pad.position = PAD_SPOTS.get(id, Vector3(0, 0, 9))
        world.add_child(pad)
        price_pads[id] = pad
    player = Player.new()
    player.name = "Player"
    player.position = PLAYER_SPAWN
    add_child(player)
    camera = FollowCamera.new()
    camera.name = "Camera"
    camera.target = player
    add_child(camera)
    hud = HUD_SCRIPT.new()
    hud.name = "Hud"
    hud.bind_player(player)
    add_child(hud)
    EventBus.purchased.connect(_on_purchased)


func _build_environment() -> void:
    var env := WorldEnvironment.new()
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.62, 0.74, 0.9)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.75, 0.8, 0.9)
    e.ambient_light_energy = 0.9
    env.environment = e
    add_child(env)
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-52, -28, 0)
    light.light_energy = 1.1
    light.shadow_enabled = true
    add_child(light)


func _build_terrain() -> void:
    # 雪地(大)與沙灘(可活動區),純外觀;活動邊界用隱形牆
    world.add_child(VisualFactory.box(Vector3(60, 0.2, 70), Color(0.93, 0.95, 0.98), Vector3(0, -0.12, -5)))
    world.add_child(VisualFactory.box(Vector3(18, 0.06, 15), Color(0.88, 0.76, 0.6), Vector3(0, -0.02, 3.5)))
    _wall(Vector3(-9.6, 1, 0), Vector3(0.4, 2, 24))
    _wall(Vector3(9.6, 1, 0), Vector3(0.4, 2, 24))
    _wall(Vector3(0, 1, 11.2), Vector3(20, 2, 0.4))
    _wall(Vector3(0, 1, -11.2), Vector3(20, 2, 0.4))
    # 柵欄(外觀):沙灘南邊與東西兩側
    for x in [-9.0, 9.0]:
        world.add_child(VisualFactory.box(Vector3(0.25, 0.9, 15), Color(0.8, 0.62, 0.42), Vector3(x, 0.45, 3.5)))
    world.add_child(VisualFactory.box(Vector3(18, 0.9, 0.25), Color(0.8, 0.62, 0.42), Vector3(0, 0.45, 11.0)))
    # 幾棵雪松
    for p in [Vector3(-13, 0, 2), Vector3(-12, 0, 8), Vector3(13, 0, -2), Vector3(12.5, 0, 9), Vector3(-14, 0, -6), Vector3(14, 0, -9)]:
        world.add_child(VisualFactory.cylinder(0.2, 1.0, Color(0.45, 0.3, 0.2), p + Vector3(0, 0.5, 0)))
        world.add_child(VisualFactory.box(Vector3(1.6, 1.6, 1.6), Color(0.86, 0.92, 0.96), p + Vector3(0, 1.6, 0)))
        world.add_child(VisualFactory.box(Vector3(1.0, 1.2, 1.0), Color(0.86, 0.92, 0.96), p + Vector3(0, 2.8, 0)))


func _wall(pos: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.collision_layer = 1 << (Carrier.TERRAIN_LAYER - 1)
    body.collision_mask = 0
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    body.add_child(shape)
    body.position = pos
    world.add_child(body)


## 魚欄裝飾:北邊的深水池 + 柵欄 + 閘門 + 幾條裝飾魚(抓不到)
func _build_pen_decoration() -> void:
    var deep := VisualFactory.box(Vector3(16, 0.12, 5), Color(0.2, 0.45, 0.85), Vector3(0, -0.04, -14.0))
    world.add_child(deep)
    for i in 17:
        var x := -8.0 + float(i)
        if absf(x) <= 1.5:
            continue
        world.add_child(VisualFactory.cylinder(0.14, 1.1, Color(0.82, 0.62, 0.4), Vector3(x, 0.55, -11.5)))
    world.add_child(VisualFactory.box(Vector3(3.2, 1.0, 0.3), Color(0.9, 0.6, 0.3), Vector3(0, 0.5, -11.5)))
    world.add_child(VisualFactory.box(Vector3(16, 0.3, 0.3), Color(0.82, 0.62, 0.4), Vector3(0, 0.95, -11.5)))
    for i in 14:
        var f := Fish.new()
        f.rect = Rect2(-7.5, -16.0, 15.0, 4.0)
        f.position = f.random_point()
        world.add_child(f)


func _add_station(spot_id: String) -> Station:
    var def := GameData.station("cutting_table")
    var s := Station.create(def)
    s.name = "Station_%s" % spot_id
    s.position = STATION_SPOTS.get(spot_id, Vector3.ZERO)
    world.add_child(s)
    stations.append(s)
    for h in helpers:
        if h.station == null:
            h.station = s
    return s


func spawn_helper(role: String) -> Helper:
    var h := Helper.new()
    h.role = role
    h.name = "Helper_%d" % (helpers.size() + 1)
    h.fish_area = fish_area
    h.station = stations[0] if not stations.is_empty() else null
    h.position = HELPER_SPAWN
    add_child(h)
    helpers.append(h)
    _spawn_flash(HELPER_SPAWN)
    EventBus.helper_hired.emit(role, h)
    EventBus.notice.emit(tr("NOTICE_HIRED"))
    return h


func _spawn_flash(pos: Vector3) -> void:
    var ring := VisualFactory.cylinder(0.9, 0.08, Color(0.75, 0.45, 1.0, 0.8), pos + Vector3(0, 0.1, 0))
    ring.material_override = VisualFactory.material(Color(0.75, 0.45, 1.0, 0.8), Color(0.6, 0.3, 1.0), true)
    world.add_child(ring)
    var tw := create_tween()
    tw.set_parallel(true)
    tw.tween_property(ring, "scale", Vector3(2.5, 1.0, 2.5), 0.5)
    tw.tween_property(ring, "transparency", 1.0, 0.5)
    tw.chain().tween_callback(ring.queue_free)


func _on_purchased(_id: String, effect: Dictionary) -> void:
    match str(effect.get("type", "")):
        "hire":
            spawn_helper(str(effect.get("role", "fisher")))
        "unlock":
            var target := str(effect.get("target", ""))
            if STATION_SPOTS.has(target):
                _add_station(target)
