class_name DB
## Все игровые данные из папки data/. Грузится один раз при старте.

static var classes: Dictionary = {}
static var bases: Dictionary = {}
static var affixes: Array = []
static var bands: Array = []
static var rare_mods: Array = []
static var currency: Array = []
static var pools: Dictionary = {}
static var corrupt_outcomes: Array = []
static var corrupt_gifts: Array = []
static var talents: Dictionary = {}
static var dungeons: Array = []
static var start: Dictionary = {}
static var loaded := false

const DAMAGE_TYPES := ["phys", "fire", "cold", "lightning", "chaos", "arcane", "holy"]
const ELEMENTS := ["fire", "cold", "lightning"]
const TYPE_NAMES := {"phys": "физ", "fire": "огонь", "cold": "холод", "lightning": "молния", "chaos": "хаос", "arcane": "тайная", "holy": "свет"}
const SLOTS := ["weapon", "offhand", "helmet", "armour", "gloves", "boots", "belt", "amulet", "ring1", "ring2"]
const SLOT_NAMES := {"weapon": "Оружие", "offhand": "Левая рука", "helmet": "Шлем", "armour": "Нагрудник",
	"gloves": "Перчатки", "boots": "Сапоги", "belt": "Пояс", "amulet": "Амулет", "ring1": "Кольцо", "ring2": "Кольцо", "ring": "Кольцо"}
const RARITY_NAMES := {"normal": "Обычный", "magic": "Магический", "rare": "Редкий"}
const ROLE_NAMES := {"tank": "танк", "healer": "лекарь", "dps": "урон", "support": "поддержка", "offtank": "урон и офтанк"}
const RARITY_COLORS := {"normal": "#c8c8c8", "magic": "#7f8fff", "rare": "#ffd75a"}


static func ensure() -> void:
	if loaded:
		return
	classes = _read("res://data/classes.json")
	bases = _read("res://data/bases.json")
	affixes = _read("res://data/affixes.json")["affixes"]
	var en: Dictionary = _read("res://data/enemies.json")
	bands = en["bands"]
	rare_mods = en["rare_mods"]
	var cur: Dictionary = _read("res://data/currency.json")
	currency = cur["currency"]
	pools = cur["pools"]
	corrupt_outcomes = cur["corrupt_outcomes"]
	corrupt_gifts = cur["corrupt_gifts"]
	classes.erase("_help")
	talents = _read("res://data/talents.json")
	talents.erase("_help")
	var dg: Dictionary = _read("res://data/dungeons.json")
	dungeons = dg["dungeons"]
	start = dg["start"]
	loaded = true


static func _read(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(f.get_as_text())


static func band_for(floor_n: int) -> Dictionary:
	var result: Dictionary = bands[0]
	for b in bands:
		if floor_n >= int(b["from"]):
			result = b
	return result


const STAT_TEXT := {
	"flat_phys": "+%s к физическому урону", "flat_fire": "+%s к урону от огня",
	"flat_cold": "+%s к урону от холода", "flat_lightning": "+%s к урону от молнии",
	"flat_chaos": "+%s к урону хаосом", "inc_dmg": "%s%% увеличение урона",
	"inc_elemental": "%s%% увеличение урона от стихий", "inc_speed": "%s%% увеличение скорости",
	"crit_chance": "+%s%% к базовому шансу крита", "armour": "+%s к броне", "life": "+%s к здоровью",
	"res_fire": "+%s%% к сопротивлению огню", "res_cold": "+%s%% к сопротивлению холоду",
	"res_lightning": "+%s%% к сопротивлению молнии", "res_chaos": "+%s%% к сопротивлению хаосу",
	"res_all_ele": "+%s%% ко всем сопротивлениям стихиям", "crit_multi": "+%s%% к множителю крита",
	"flat_heal": "+%s к силе исцеления", "inc_heal": "%s%% увеличение исцеления", "inc_crit": "%s%% увеличение шанса крита",
	"inc_phys": "%s%% увеличение физического урона", "regen": "%s%% здоровья в секунду", "inc_life": "%s%% увеличение здоровья",
}


static func stat_text(stat: String, value: Variant) -> String:
	if STAT_TEXT.has(stat):
		return STAT_TEXT[stat] % str(value)
	return "%s %s" % [stat, value]


static func currency_def(id: String) -> Dictionary:
	for c in currency:
		if c["id"] == id:
			return c
	return {}


## Ветка героя (словарь из classes.json)
static func spec(hero: Dictionary) -> Dictionary:
	return classes[hero["cls"]]["specs"][hero["spec"]]


static func role(hero: Dictionary) -> String:
	return spec(hero)["role"]


static func hero_name(hero: Dictionary) -> String:
	return "%s (%s)" % [classes[hero["cls"]]["name"], spec(hero)["name"]]


static func has_talent_flag(hero: Dictionary, flag: String) -> bool:
	for tier in talent_tiers(hero):
		var pick = hero.get("talents", {}).get(str(int(tier["lvl"])))
		if pick != null and int(hero["lvl"]) >= int(tier["lvl"]) and int(pick) < tier["options"].size():
			if tier["options"][int(pick)].get("stats", {}).has(flag):
				return true
	return false


## Ярусы талантов, которые есть у героя (общие для класса + своей ветки)
static func talent_tiers(hero: Dictionary) -> Array:
	return talents.get(hero["cls"], []).filter(func(tr): return not tr.has("spec") or tr["spec"] == hero["spec"])


## В какие слоты героя встаёт предмет
static func equip_slots(item: Dictionary, hero: Dictionary = {}) -> Array:
	if item["slot"] == "ring":
		return ["ring1", "ring2"]
	if item["kind"] == "greatsword" and not hero.is_empty() and has_talent_flag(hero, "titan_grip"):
		return ["weapon", "offhand"]
	return [item["slot"]]


## Может ли герой носить предмет (оружие и левая рука зависят от класса и ветки)
static func can_use(hero: Dictionary, item: Dictionary) -> bool:
	var sp := spec(hero)
	var cls: Dictionary = classes[hero["cls"]]
	if item["slot"] == "weapon":
		return item["kind"] in sp.get("weapons", cls["weapons"])
	if item["slot"] == "offhand":
		return item["kind"] in sp.get("offhands", cls["offhands"])
	return true


static func is_two_handed(item) -> bool:
	return item != null and item["kind"] == "greatsword"


static func dungeon(id: String) -> Dictionary:
	for d in dungeons:
		if d["id"] == id:
			return d
	return {}
