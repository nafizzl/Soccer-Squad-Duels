-- ReplicatedStorage/Data/CardDatabase.lua
local CardDatabaseAllTime = require(script.Parent.CardDatabaseAllTime)
local CardDatabaseCurrent = require(script.Parent.CardDatabaseCurrent)

export type CardRarity = CardDatabaseAllTime.CardRarity
export type CardPosition = CardDatabaseAllTime.CardPosition
export type CardData = CardDatabaseAllTime.CardData

local CardDatabase = {
	AllTime = CardDatabaseAllTime,
	Current = CardDatabaseCurrent,
}

return CardDatabase
