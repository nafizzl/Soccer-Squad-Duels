local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

local CardDatabase = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("CardDatabase"))
local DuelEvents = require(ReplicatedStorage:WaitForChild("DuelEvents"))

-- 1. Setup Legacy Remote Event (ExitQueueEvent)
local exitQueueEvent = ReplicatedStorage:FindFirstChild("ExitQueueEvent")
if not exitQueueEvent then
    exitQueueEvent = Instance.new("RemoteEvent")
    exitQueueEvent.Name = "ExitQueueEvent"
    exitQueueEvent.Parent = ReplicatedStorage
end

-- 2. State tracking
local fieldsState = {} 
local playerCooldowns = {} -- [Player] = clockTime
local COOLDOWN_DURATION = 2.0
local playerOriginalStats = {} -- [Player] = { WalkSpeed, JumpPower, etc. }

-- Position Group mapping for eligibility checks
local POSITION_GROUPS = {
    Center = { "CM", "CAM", "CDM" },
    Attacker = { "ST", "CF", "LW", "RW" },
    Defender = { "CB", "LB", "RB", "LWB", "RWB" },
    Keeper = { "GK" },
}

local function isCardEligibleForPosition(cardData, targetPos: string): boolean
    local targetClean = targetPos:gsub("%d+", ""):gsub("Slot", "") -- e.g. "CB1Slot" -> "CB"
    
    if cardData.Position == targetClean then return true end
    if cardData.AlternativePositions and table.find(cardData.AlternativePositions, targetClean) then return true end
    
    for _, group in pairs(POSITION_GROUPS) do
        if table.find(group, targetClean) then
            if table.find(group, cardData.Position) then return true end
            if cardData.AlternativePositions then
                for _, alt in ipairs(cardData.AlternativePositions) do
                    if table.find(group, alt) then return true end
                end
            end
        end
    end
    return false
end

local function getPlayerMatch(player)
    for i = 1, 8 do
        local state = fieldsState[i]
        if state and (state.player1 == player or state.player2 == player) then
            local isP1 = (state.player1 == player)
            local opponent = isP1 and state.player2 or state.player1
            return i, state, isP1, opponent
        end
    end
    return nil, nil, nil, nil
end

local function isPlayerQueued(player)
    local fieldIndex = getPlayerMatch(player)
    return fieldIndex ~= nil
end

local function getOrCreateLabel(anchorPart, guiName)
    if not anchorPart then return nil end
    
    for _, child in ipairs(anchorPart:GetChildren()) do
        if child:IsA("SurfaceGui") then
            child:Destroy()
        end
    end
    
    local billboard = anchorPart:FindFirstChild(guiName)
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = guiName
        billboard.Size = UDim2.new(12, 0, 4, 0)
        billboard.AlwaysOnTop = true
        billboard.StudsOffset = Vector3.new(0, 0, 0)
        billboard.Adornee = anchorPart
        
        local label = Instance.new("TextLabel")
        label.Name = "TextLabel"
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.TextStrokeTransparency = 0
        label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        label.TextScaled = true
        label.Font = Enum.Font.FredokaOne
        label.TextXAlignment = Enum.TextXAlignment.Center
        label.TextYAlignment = Enum.TextYAlignment.Center
        label.Parent = billboard
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 2
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Parent = label
        
        billboard.Parent = anchorPart
    end
    return billboard:FindFirstChild("TextLabel")
end

local function updateAnchorText(anchorPart, text, color)
    local label = getOrCreateLabel(anchorPart, "StatusBillboard")
    if label then
        label.Text = text
        if color then
            label.TextColor3 = color
        end
    end
end

local releasePlayer -- forward declaration

local function unlockPlayer(player, spotName, fieldIndex)
    playerCooldowns[player] = os.clock() + COOLDOWN_DURATION

    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local exitGui = playerGui:FindFirstChild("ExitQueue")
        if exitGui then exitGui.Enabled = false end
        local duelGui = playerGui:FindFirstChild("DuelGui")
        if duelGui then duelGui.Enabled = false end
    end

    local character = player.Character
    if character then
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local stats = playerOriginalStats[player]
        if humanoid and stats then
            humanoid.WalkSpeed = stats.WalkSpeed
            humanoid.UseJumpPower = stats.UseJumpPower
            if stats.UseJumpPower then
                humanoid.JumpPower = stats.JumpPower
            else
                humanoid.JumpHeight = stats.JumpHeight
            end
        end
        playerOriginalStats[player] = nil

        local rootPart = character:FindFirstChild("HumanoidRootPart")
        if rootPart then
            rootPart.Anchored = false
            local field = workspace:FindFirstChild("Soccer Field " .. fieldIndex)
            if field then
                local spot = field:FindFirstChild(spotName)
                if spot then
                    local centerCFrame, size = spot:GetBoundingBox()
                    local look = centerCFrame.LookVector
                    local exitOffset = centerCFrame * CFrame.new(0, 0, 10)
                    local uprightPosition = Vector3.new(exitOffset.Position.X, centerCFrame.Position.Y - size.Y / 2 + 3.0, exitOffset.Position.Z)
                    local uprightCFrame = CFrame.lookAt(uprightPosition, uprightPosition + Vector3.new(look.X, 0, look.Z))
                    rootPart.CFrame = uprightCFrame
                end
            end
        end
    end
end

releasePlayer = function(player)
    for i = 1, 8 do
        local state = fieldsState[i]
        if state then
            if state.player1 == player or state.player2 == player then
                local spotName = (state.player1 == player) and "Player 1 Spot" or "Player 2 Spot"
                if state.player1 == player then state.player1 = nil else state.player2 = nil end
                state.countdownActive = false
                state.matchActive = false
                unlockPlayer(player, spotName, i)
                return
            end
        end
    end
end

local function updateFieldLabels(fieldIndex)
    local state = fieldsState[fieldIndex]
    local field = workspace:FindFirstChild("Soccer Field " .. fieldIndex)
    if not field then return end

    local statusAnchor = field:FindFirstChild("StatusAnchor", true)
    local countdownAnchor = field:FindFirstChild("CountdownAnchor", true)

    if state.countdownActive or state.matchActive then return end

    local p1 = state.player1
    local p2 = state.player2

    if not p1 and not p2 then
        updateAnchorText(statusAnchor, "", Color3.fromRGB(255, 255, 255))
        updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
    elseif p1 and p2 then
        task.spawn(function()
            if state.countdownActive or state.matchActive then return end
            state.countdownActive = true

            updateAnchorText(statusAnchor, "Starting Game...", Color3.fromRGB(255, 255, 255))

            for i = 3, 0, -1 do
                if not state.player1 or not state.player2 then
                    state.countdownActive = false
                    updateFieldLabels(fieldIndex)
                    return
                end
                updateAnchorText(countdownAnchor, tostring(i), Color3.fromRGB(255, 255, 255))
                task.wait(1)
            end

            if not state.player1 or not state.player2 then
                state.countdownActive = false
                updateFieldLabels(fieldIndex)
                return
            end

            state.countdownActive = false
            state.matchActive = true
            state.p1Draft = {}
            state.p2Draft = {}
            state.p1Candidates = {}
            state.p2Candidates = {}

            updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
            updateAnchorText(statusAnchor, "Match Active!", Color3.fromRGB(0, 255, 0))

            local players = {state.player1, state.player2}
            for _, p in ipairs(players) do
                local pGui = p:FindFirstChild("PlayerGui")
                if pGui then
                    local exitGui = pGui:FindFirstChild("ExitQueue")
                    if exitGui then exitGui.Enabled = false end
                    local duelGui = pGui:FindFirstChild("DuelGui")
                    if duelGui then duelGui.Enabled = true end
                end
            end

            if state.player1 and state.player2 then
                DuelEvents.StartDuelEvent:FireClient(state.player1, state.player2.Name)
                DuelEvents.StartDuelEvent:FireClient(state.player2, state.player1.Name)
            end
        end)
    else
        updateAnchorText(statusAnchor, "Waiting for Opponent...", Color3.fromRGB(255, 255, 255))
        updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
    end
end

-- Central Forfeit and Disconnect Handler with 3-second billboard auto-clear
local function handleForfeit(player, customMessage)
    local fieldIndex, state, isP1, opponent = getPlayerMatch(player)
    if fieldIndex and state then
        state.matchActive = false
        state.countdownActive = false

        local field = workspace:FindFirstChild("Soccer Field " .. fieldIndex)
        if field then
            local statusAnchor = field:FindFirstChild("StatusAnchor", true)
            local msg = customMessage or (player.Name .. " forfeited")
            updateAnchorText(statusAnchor, msg, Color3.fromRGB(255, 50, 50))

            task.spawn(function()
                task.wait(3)
                if not state.countdownActive and not state.matchActive then
                    updateFieldLabels(fieldIndex)
                end
            end)
        end

        if opponent then
            DuelEvents.ForfeitEvent:FireClient(opponent, player.Name)
            releasePlayer(opponent)
        end

        releasePlayer(player)
    end
end

local function lockPlayer(player, spotModel, spotName, fieldIndex)
    local character = player.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end

    local currentTime = os.clock()
    if playerCooldowns[player] and currentTime < playerCooldowns[player] then return end

    local state = fieldsState[fieldIndex]
    if spotName == "Player 1 Spot" then
        state.player1 = player
    else
        state.player2 = player
    end

    playerOriginalStats[player] = {
        WalkSpeed = humanoid.WalkSpeed,
        JumpPower = humanoid.JumpPower,
        JumpHeight = humanoid.JumpHeight,
        UseJumpPower = humanoid.UseJumpPower
    }
    humanoid.WalkSpeed = 0
    if humanoid.UseJumpPower then
        humanoid.JumpPower = 0
    else
        humanoid.JumpHeight = 0
    end

    local centerCFrame, size = spotModel:GetBoundingBox()
    local uprightPosition = Vector3.new(centerCFrame.Position.X, centerCFrame.Position.Y - size.Y / 2 + 3.0, centerCFrame.Position.Z)
    local look = centerCFrame.LookVector
    local uprightCFrame = CFrame.lookAt(uprightPosition, uprightPosition + Vector3.new(look.X, 0, look.Z))
    
    rootPart.CFrame = uprightCFrame
    rootPart.AssemblyLinearVelocity = Vector3.zero
    rootPart.AssemblyAngularVelocity = Vector3.zero

    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
            track:Stop(0.1)
        end
    end

    task.wait(0.05)
    rootPart.Anchored = true

    local playerGui = player:FindFirstChild("PlayerGui")
    if playerGui then
        local exitGui = playerGui:FindFirstChild("ExitQueue")
        if exitGui then exitGui.Enabled = true end
    end

    local diedConnection
    diedConnection = humanoid.Died:Connect(function()
        diedConnection:Disconnect()
        handleForfeit(player, player.Name .. " forfeited")
    end)
end

-- 3. Initialize touched connections
local function setupSpotConnections()
    for i = 1, 8 do
        fieldsState[i] = {
            player1 = nil,
            player2 = nil,
            countdownActive = false,
            matchActive = false,
            p1Draft = {},
            p2Draft = {},
            p1Candidates = {},
            p2Candidates = {}
        }
        
        local fieldName = "Soccer Field " .. i
        local field = workspace:WaitForChild(fieldName, 5)
        if field then
            local p1Spot = field:WaitForChild("Player 1 Spot", 5)
            local p2Spot = field:WaitForChild("Player 2 Spot", 5)
            
            if p1Spot then
                for _, part in ipairs(p1Spot:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Touched:Connect(function(otherPart)
                            local character = otherPart.Parent
                            local player = Players:GetPlayerFromCharacter(character)
                            if player and not isPlayerQueued(player) and not fieldsState[i].player1 then
                                lockPlayer(player, p1Spot, "Player 1 Spot", i)
                                updateFieldLabels(i)
                            end
                        end)
                    end
                end
            end
            
            if p2Spot then
                for _, part in ipairs(p2Spot:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Touched:Connect(function(otherPart)
                            local character = otherPart.Parent
                            local player = Players:GetPlayerFromCharacter(character)
                            if player and not isPlayerQueued(player) and not fieldsState[i].player2 then
                                lockPlayer(player, p2Spot, "Player 2 Spot", i)
                                updateFieldLabels(i)
                            end
                        end)
                    end
                end
            end
            
            updateFieldLabels(i)
        end
    end
end

task.spawn(setupSpotConnections)

-- 4. Listen for Legacy ExitQueueEvent & ForfeitEvent & Player Disconnect
exitQueueEvent.OnServerEvent:Connect(function(player)
    releasePlayer(player)
end)

DuelEvents.ForfeitEvent.OnServerEvent:Connect(function(player)
    handleForfeit(player)
end)

Players.PlayerRemoving:Connect(function(player)
    handleForfeit(player, player.Name .. " forfeited")
    playerCooldowns[player] = nil
end)

-- 5. Roll Cards Request
DuelEvents.RollCardsEvent.OnServerEvent:Connect(function(player, slotFrameName)
    local fieldIndex, state, isP1, opponent = getPlayerMatch(player)
    if not fieldIndex or not state or not state.matchActive then return end

    local pool = {}
    for _, card in pairs(CardDatabase.Current) do
        if isCardEligibleForPosition(card, slotFrameName) then
            table.insert(pool, card)
        end
    end

    if #pool == 0 then
        for _, card in pairs(CardDatabase.Current) do
            table.insert(pool, card)
        end
    end

    local candidates = {}
    local usedIndices = {}
    for c = 1, 3 do
        local idx
        repeat
            idx = math.random(1, #pool)
        until not usedIndices[idx] or #usedIndices >= #pool
        usedIndices[idx] = true
        table.insert(candidates, pool[idx])
    end

    -- Save candidate roll state using unique slotFrameName (e.g. CB1, CB2)
    if isP1 then
        state.p1Candidates = state.p1Candidates or {}
        state.p1Candidates[slotFrameName] = candidates
    else
        state.p2Candidates = state.p2Candidates or {}
        state.p2Candidates[slotFrameName] = candidates
    end

    local reelPool = {}
    for d = 1, 25 do
        local randCard = pool[math.random(1, #pool)]
        table.insert(reelPool, randCard)
    end

    DuelEvents.RollCardsEvent:FireClient(player, slotFrameName, candidates, reelPool)
end)

-- 6. Card Selected Event (Validates candidate index 1, 2, or 3 across 11 unique slot keys)
DuelEvents.CardSelectedEvent.OnServerEvent:Connect(function(player, slotFrameName, cardChoice)
    local fieldIndex, state, isP1, opponent = getPlayerMatch(player)
    if not fieldIndex or not state or not state.matchActive then return end

    local cardData = nil
    if type(cardChoice) == "number" then
        local candTable = isP1 and state.p1Candidates and state.p1Candidates[slotFrameName] or state.p2Candidates and state.p2Candidates[slotFrameName]
        if candTable and candTable[cardChoice] then
            cardData = candTable[cardChoice]
        end
    elseif type(cardChoice) == "table" then
        cardData = cardChoice
    end

    if not cardData then return end

    local myDraft = isP1 and state.p1Draft or state.p2Draft
    myDraft[slotFrameName] = cardData

    if opponent then
        DuelEvents.OpponentSlotUpdatedEvent:FireClient(opponent, slotFrameName, cardData.Rarity)
    end

    local p1Count = 0
    for _ in pairs(state.p1Draft) do p1Count += 1 end
    local p2Count = 0
    for _ in pairs(state.p2Draft) do p2Count += 1 end

    -- Check if both players have selected all 11 unique formation slots
    if p1Count >= 11 and p2Count >= 11 then
        local p1Sum, p2Sum = 0, 0
        for _, card in pairs(state.p1Draft) do p1Sum += card.OVR end
        for _, card in pairs(state.p2Draft) do p2Sum += card.OVR end

        local p1FinalOVR = math.floor(p1Sum / 11)
        local p2FinalOVR = math.floor(p2Sum / 11)

        -- Notify clients with final OVRs
        if state.player1 then
            DuelEvents.MatchCompletedEvent:FireClient(state.player1, p1FinalOVR, p2FinalOVR)
        end
        if state.player2 then
            DuelEvents.MatchCompletedEvent:FireClient(state.player2, p2FinalOVR, p1FinalOVR)
        end

        task.spawn(function()
            local winnerText = "Match Tied!"
            if p1FinalOVR > p2FinalOVR then
                winnerText = (state.player1 and state.player1.Name or "Player 1") .. " won!"
            elseif p2FinalOVR > p1FinalOVR then
                winnerText = (state.player2 and state.player2.Name or "Player 2") .. " won!"
            end

            -- Update 3D Billboard Gui on field
            local field = workspace:FindFirstChild("Soccer Field " .. fieldIndex)
            if field then
                local statusAnchor = field:FindFirstChild("StatusAnchor", true)
                updateAnchorText(statusAnchor, winnerText, Color3.fromRGB(255, 215, 0))
            end

            task.wait(5)

            state.matchActive = false
            local p1Ref = state.player1
            local p2Ref = state.player2

            if p1Ref then releasePlayer(p1Ref) end
            if p2Ref then releasePlayer(p2Ref) end

            -- Reset field status text back to default after 5 seconds
            task.wait(5)
            if not state.countdownActive and not state.matchActive then
                updateFieldLabels(fieldIndex)
            end
        end)
    end
end)