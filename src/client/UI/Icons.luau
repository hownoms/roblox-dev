--!strict
-- Emoji/text icons only (no image asset ids). Keep to widely supported emoji (Unicode <= 12).
local Icons = {}

Icons.Coins = "💰"
Icons.Tokens = "🔷"
Icons.Rebirth = "♻️"
Icons.Sand = "⏳"
Icons.Backpack = "🎒"
Icons.Depth = "⛏️"
Icons.Shop = "🛒"
Icons.Eggs = "🥚"
Icons.Pets = "🐾"
Icons.Index = "📖"
Icons.Quests = "📜"
Icons.Daily = "🎁"
Icons.Store = "💎"
Icons.Settings = "⚙️"
Icons.Beach = "⛱️"
Icons.Garage = "🚜"
Icons.Surface = "⬆️"
Icons.Sell = "💸"
Icons.AutoDig = "🤖"
Icons.Lock = "🔒"
Icons.Check = "✅"
Icons.Close = "✖"
Icons.Star = "⭐"
Icons.Robux = "R$"
Icons.Power = "💪"
Icons.Speed = "⚡"
Icons.Radius = "📏"
Icons.Multiplier = "✖️"
Icons.Hand = "👆"
Icons.Arrow = "⬇️"

Icons.Layers = {
	dry_sand = "🏖️",
	wet_sand = "🌊",
	shell_bed = "🐚",
	tidal_clay = "🦀",
	pirate_cove = "🏴‍☠️",
	shipwreck = "⚓",
	fossil_bed = "🦖",
	bedrock = "⛰️",
	crystal_caverns = "💎",
	frozen_abyss = "🧊",
	ancient_ruins = "🏛️",
	magma_chamber = "🌋",
	obsidian_depths = "🖤",
	alien_hive = "👽",
	the_core = "🌟",
} :: { [string]: string }

Icons.PetShapes = {
	Crab = "🦀",
	Bird = "🐦",
	Star = "⭐",
	Turtle = "🐢",
	Fish = "🐟",
	Squid = "🦑",
	Blob = "💧",
	Mole = "🐹",
	Dino = "🦖",
	Dragon = "🐉",
	Golem = "🗿",
	Seal = "🐳",
} :: { [string]: string }

Icons.BackpackShapes = {
	Bucket = "🧺",
	Bag = "👜",
	Box = "📦",
	Barrel = "🛢️",
	Cart = "🛒",
	Vehicle = "🚜",
	Orb = "🔮",
} :: { [string]: string }

Icons.TreasureShapes = {
	Coin = "🥇",
	Cap = "🧢",
	Shell = "🐚",
	Bottle = "🍾",
	Chest = "🧰",
	Gem = "💎",
	Bone = "🦴",
	Skull = "💀",
	Orb = "🔮",
	Crown = "👑",
	Tablet = "📜",
	Egg = "🥚",
	Anchor = "⚓",
	Wheel = "☸️",
	Shard = "🔷",
	Box = "📦",
} :: { [string]: string }

Icons.BoostKinds = {
	Sand = "⏳",
	Luck = "🍀",
	Coins = "💰",
	Speed = "⚡",
} :: { [string]: string }

Icons.Events = {
	HighTide = "🌊",
	GoldenHour = "🌅",
} :: { [string]: string }

function Icons.Layer(id: string): string
	return Icons.Layers[id] or "⛏️"
end

function Icons.PetShape(shape: string): string
	return Icons.PetShapes[shape] or "🐾"
end

function Icons.Event(id: string, kind: string?): string
	return Icons.Events[id] or (kind and Icons.BoostKinds[kind]) or "🎉"
end

return Icons
