-- ReplicatedStorage/DuelEvents.lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DuelEvents = {}

local function getOrCreateRemote(name: string): RemoteEvent
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

DuelEvents.StartDuelEvent = getOrCreateRemote("StartDuelEvent")
DuelEvents.ForfeitEvent = getOrCreateRemote("ForfeitEvent")
DuelEvents.RollCardsEvent = getOrCreateRemote("RollCardsEvent")
DuelEvents.CardSelectedEvent = getOrCreateRemote("CardSelectedEvent")
DuelEvents.OpponentSlotUpdatedEvent = getOrCreateRemote("OpponentSlotUpdatedEvent")
DuelEvents.MatchCompletedEvent = getOrCreateRemote("MatchCompletedEvent")

return DuelEvents
