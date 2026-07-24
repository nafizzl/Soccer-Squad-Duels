-- StarterPlayer/StarterPlayerScripts/Controllers/DuelGuiController.client.lua
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local DuelGui = PlayerGui:WaitForChild("DuelGui")

local DuelEvents = require(ReplicatedStorage:WaitForChild("DuelEvents"))
local RarityColors = require(ReplicatedStorage:WaitForChild("Data"):WaitForChild("RarityColors"))

local Templates = ReplicatedStorage:WaitForChild("Templates")
local TeamViewSlotTemplates = Templates:WaitForChild("TeamViewSlot")
local EmptySlotTemplate = TeamViewSlotTemplates:WaitForChild("EmptySlotView")
local SelectedSlotTemplate = TeamViewSlotTemplates:WaitForChild("SelectedSlotView")
local CardRolledTemplate = Templates:WaitForChild("CardRolledSlot"):WaitForChild("CardRolledSlot")

local DuelMenu = DuelGui:WaitForChild("DuelMenu")
local YourTeamFrame = DuelMenu:WaitForChild("YourTeamFrame")
local YourTeamView = YourTeamFrame:WaitForChild("YourTeamView")
local YourOVRValue = YourTeamFrame:WaitForChild("YourOVRValue")

local OpponentTeamFrame = DuelMenu:WaitForChild("OpponentTeamFrame")
local OpponentTeamView = OpponentTeamFrame:WaitForChild("OpponentTeamView")
local OpponentOVRValue = OpponentTeamFrame:WaitForChild("OpponentOVRValue")
local OpponentTeamLabel = OpponentTeamFrame:WaitForChild("OpponentTeamLabel")

local ExitButtonFrame = DuelMenu:WaitForChild("ExitButtonFrame")
local ExitButton = ExitButtonFrame:WaitForChild("ExitButton")

local CardSelectionFrame = DuelMenu:WaitForChild("CardSelectionFrame")
local CardSlot1 = CardSelectionFrame:WaitForChild("CardSlot1")
local CardSlot2 = CardSelectionFrame:WaitForChild("CardSlot2")
local CardSlot3 = CardSelectionFrame:WaitForChild("CardSlot3")

CardSlot1.ClipsDescendants = true
CardSlot2.ClipsDescendants = true
CardSlot3.ClipsDescendants = true

-- Audio setup: Multi-voice tick sound pool to prevent audio cutoff
local tickSound = Instance.new("Sound")
tickSound.SoundId = "rbxassetid://6042053626"
tickSound.Volume = 0.4
tickSound.Parent = DuelGui

local function safePlayTick()
    task.spawn(function()
        pcall(function()
            local soundClone = tickSound:Clone()
            soundClone.Parent = DuelGui
            soundClone:Play()
            soundClone.Ended:Connect(function()
                soundClone:Destroy()
            end)
        end)
    end)
end

-- State Tracking
local selectedCards = {}
local activeSlotName = nil
local activeSlotKey = nil
local isRolling = false

local activeTweens = {}
local activeConnections = {}

-- Cache template elements in O(1) single-pass lookup table
local cardElementCache = setmetatable({}, {__mode = "k"})

local function cacheCardElements(frame)
    if cardElementCache[frame] then return cardElementCache[frame] end

    local elements = {
        ovr = frame:FindFirstChild("OVRValue", true),
        pos = frame:FindFirstChild("SlotPosition", true) 
            or frame:FindFirstChild("CardPosition", true) 
            or frame:FindFirstChild("PositionLabel", true)
            or frame:FindFirstChild("Position", true)
            or frame:FindFirstChild("Pos", true),
        name = frame:FindFirstChild("CardName", true),
        innerBg = frame:FindFirstChild("CardBackground", true) or frame:FindFirstChild("InnerFrame", true),
        statsContainer = frame:FindFirstChild("Stats", true) or frame:FindFirstChild("StatsGrid", true) or frame:FindFirstChild("StatsFrame", true),
        stats = {}
    }

    local statList = {"PAC", "SHO", "PAS", "DRI", "DEF", "PHY"}
    for _, statName in ipairs(statList) do
        elements.stats[statName] = {
            value = frame:FindFirstChild(statName .. "Value", true),
            title = frame:FindFirstChild(statName .. "Label", true) or frame:FindFirstChild(statName, true)
        }
    end

    cardElementCache[frame] = elements
    return elements
end

local function cleanupRollingState()
    isRolling = false
    
    for _, tween in ipairs(activeTweens) do
        if tween then tween:Cancel() end
    end
    table.clear(activeTweens)

    for _, conn in ipairs(activeConnections) do
        if conn then conn:Disconnect() end
    end
    table.clear(activeConnections)

    pcall(function()
        tickSound:Stop()
    end)
end

local POSITION_NAMES = {
    LWSlot = "LW", STSlot = "ST", RWSlot = "RW",
    LMSlot = "LM", CMSlot = "CM", RMSlot = "RM",
    LBSlot = "LB", RBSlot = "RB", GKSlot = "GK",
    LW = "LW", ST = "ST", RW = "RW",
    LM = "LM", CM = "CM", RM = "RM",
    LB = "LB", RB = "RB", GK = "GK",
}

local function getPositionForSlot(slotFrame)
    if not slotFrame then return "CM" end
    local name = slotFrame.Name
    if POSITION_NAMES[name] then return POSITION_NAMES[name] end
    if name:find("CB") then return "CB" end
    local clean = name:gsub("Slot", ""):gsub("%d+", "")
    return #clean > 0 and clean or "CM"
end

local function populateCardInfo(frame, cardData, hideStats, overridePosition)
    if not frame or not cardData then return end
    local el = cacheCardElements(frame)

    if el.ovr then el.ovr.Text = tostring(cardData.OVR or "?") end
    if el.pos and el.pos:IsA("TextLabel") then 
        el.pos.Text = overridePosition or tostring(cardData.Position or "") 
    end
    if el.name then el.name.Text = cardData.ShortName or cardData.Name or "" end

    local color = RarityColors[cardData.Rarity] or Color3.fromRGB(40, 40, 40)
    frame.BackgroundColor3 = color
    frame.BackgroundTransparency = 0

    if el.innerBg and el.innerBg:IsA("GuiObject") then
        el.innerBg.BackgroundColor3 = color
        el.innerBg.BackgroundTransparency = 0
    end

    if el.statsContainer then
        el.statsContainer.Visible = not hideStats
    end

    if cardData.Stats then
        for statName, statObj in pairs(el.stats) do
            local val = cardData.Stats[statName] or (
                statName == "PAC" and cardData.Stats.Pace or
                statName == "SHO" and cardData.Stats.Shooting or
                statName == "PAS" and cardData.Stats.Passing or
                statName == "DRI" and cardData.Stats.Dribbling or
                statName == "DEF" and cardData.Stats.Defending or
                statName == "PHY" and cardData.Stats.Physical or 0
            )

            if statObj.value then 
                statObj.value.Text = tostring(val or 0)
                statObj.value.Visible = not hideStats
            end

            if statObj.title and statObj.title:IsA("TextLabel") and statObj.title ~= statObj.value then
                statObj.title.Visible = not hideStats
            end
        end
    end
end

local function updateAverageOVR()
    local count, sum = 0, 0
    for _, card in pairs(selectedCards) do
        count += 1
        sum += card.OVR
    end

    YourOVRValue.Text = (count == 0) and "?" or tostring(math.floor(sum / count))
end

-- Initialize Team Views dynamically matching exact position & anchor point of slot frames
local function initializeTeamViews()
    cleanupRollingState()
    selectedCards = {}
    YourOVRValue.Text = "?"
    OpponentOVRValue.Text = "?"
    CardSelectionFrame.Visible = false

    -- Setup YourTeamView with guaranteed unique keys (CB1 vs CB2)
    local cbCount = 0
    for _, child in ipairs(YourTeamView:GetChildren()) do
        if child:IsA("Frame") then
            local slotKey = child.Name
            if slotKey == "CB" or slotKey == "CBSlot" or slotKey:find("CB") then
                cbCount += 1
                slotKey = "CB" .. cbCount
            end
            child.Name = slotKey -- Guarantee unique name on client frame

            for _, old in ipairs(child:GetChildren()) do
                if old.Name == "EmptySlotView" or old.Name == "SelectedSlotView" then
                    old:Destroy()
                end
            end

            local emptyView = EmptySlotTemplate:Clone()
            emptyView.AnchorPoint = Vector2.new(0, 0)
            emptyView.Position = UDim2.new(0, 0, 0, 0)
            emptyView.Size = UDim2.new(1, 0, 1, 0)
            emptyView.Visible = true

            local posText = getPositionForSlot(child)
            local el = cacheCardElements(emptyView)
            if el.pos then el.pos.Text = posText end

            local btn = emptyView:FindFirstChild("SelectPlayerButton", true)
            if btn then
                btn.Text = "+"
                btn.MouseButton1Click:Connect(function()
                    if isRolling then return end
                    activeSlotName = child
                    activeSlotKey = slotKey -- Send unique key (e.g. CB1, CB2)
                    DuelEvents.RollCardsEvent:FireServer(slotKey)
                end)
            end

            emptyView.Parent = child
        end
    end

    -- Setup OpponentTeamView with guaranteed unique keys (CB1 vs CB2)
    local oppCbCount = 0
    for _, child in ipairs(OpponentTeamView:GetChildren()) do
        if child:IsA("Frame") then
            local slotKey = child.Name
            if slotKey == "CB" or slotKey == "CBSlot" or slotKey:find("CB") then
                oppCbCount += 1
                slotKey = "CB" .. oppCbCount
            end
            child.Name = slotKey

            for _, old in ipairs(child:GetChildren()) do
                if old.Name == "EmptySlotView" or old.Name == "SelectedSlotView" then
                    old:Destroy()
                end
            end

            local oppEmpty = EmptySlotTemplate:Clone()
            oppEmpty.AnchorPoint = Vector2.new(0, 0)
            oppEmpty.Position = UDim2.new(0, 0, 0, 0)
            oppEmpty.Size = UDim2.new(1, 0, 1, 0)
            oppEmpty.Visible = true

            local posText = getPositionForSlot(child)
            local el = cacheCardElements(oppEmpty)
            if el.pos then el.pos.Text = posText end

            local btn = oppEmpty:FindFirstChild("SelectPlayerButton", true)
            if btn then
                btn.Text = ""
                btn.Active = false
            end

            oppEmpty.Parent = child
        end
    end
end

local function bindCardSelection(cardFrame, winningCard, candidateIndex, slotKey)
    if not cardFrame or not winningCard then return end
    local targetKey = slotKey or activeSlotKey
    local displayPosition = activeSlotName and getPositionForSlot(activeSlotName) or "CM"
    
    local function onCardSelected()
        if activeSlotName and activeSlotName:IsA("Frame") then
            local emptyView = activeSlotName:FindFirstChild("EmptySlotView")
            if emptyView then emptyView:Destroy() end

            local selectedView = SelectedSlotTemplate:Clone()
            selectedView.AnchorPoint = Vector2.new(0, 0)
            selectedView.Position = UDim2.new(0, 0, 0, 0)
            selectedView.Size = UDim2.new(1, 0, 1, 0)
            selectedView.Visible = true

            populateCardInfo(selectedView, winningCard, false, displayPosition)
            selectedView.Parent = activeSlotName

            selectedCards[activeSlotName.Name] = winningCard
            updateAverageOVR()

            -- Send unique slot key (CB1, CB2, etc.) so server registers all 11 slots
            DuelEvents.CardSelectedEvent:FireServer(targetKey, candidateIndex)
        end

        CardSelectionFrame.Visible = false
        cleanupRollingState()
    end

    for _, descendant in ipairs(cardFrame:GetDescendants()) do
        if descendant:IsA("GuiButton") then
            descendant.MouseButton1Click:Connect(onCardSelected)
        end
    end

    if cardFrame:IsA("GuiButton") then
        cardFrame.MouseButton1Click:Connect(onCardSelected)
    else
        cardFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                onCardSelected()
            end
        end)
    end
end

-- Slime-RNG Vertical Reel Spinning Animation Helper
local function spinSingleSlot(slotContainer, winningCard, dummyPool, delayTime, candidateIndex, slotKey)
    if not slotContainer or not winningCard or not dummyPool then return nil end

    slotContainer.ClipsDescendants = true
    for _, old in ipairs(slotContainer:GetChildren()) do
        if old:IsA("Frame") then old:Destroy() end
    end

    if slotContainer.AbsoluteSize.Y <= 10 then
        RunService.Heartbeat:Wait()
    end

    local reelStrip = Instance.new("Frame")
    reelStrip.Name = "ReelStrip"
    reelStrip.Size = UDim2.new(1, 0, 0, 0)
    reelStrip.Position = UDim2.new(0, 0, 0, 0)
    reelStrip.AutomaticSize = Enum.AutomaticSize.Y
    reelStrip.BackgroundTransparency = 1
    reelStrip.Parent = slotContainer

    local layout = Instance.new("UIListLayout")
    layout.FillDirection = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 12)
    layout.Parent = reelStrip

    local winnerCardFrame = nil
    local totalCards = 40
    local winnerIndex = 32

    local containerHeight = slotContainer.AbsoluteSize.Y > 0 and slotContainer.AbsoluteSize.Y or 220
    local cardHeight = containerHeight * 0.88
    local dummyPoolSize = #dummyPool

    for i = 1, totalCards do
        local cardData = (i == winnerIndex) and winningCard or dummyPool[math.random(1, dummyPoolSize)]
        local cardClone = CardRolledTemplate:Clone()
        cardClone.Name = "ReelCard_" .. i
        cardClone.LayoutOrder = i
        cardClone.Size = UDim2.new(0.92, 0, 0, cardHeight)
        cardClone.Visible = true

        local aspect = cardClone:FindFirstChildOfClass("UIAspectRatioConstraint")
        if not aspect then
            aspect = Instance.new("UIAspectRatioConstraint")
            aspect.AspectRatio = 0.72
            aspect.AspectType = Enum.AspectType.FitWithinMaxSize
            aspect.DominantAxis = Enum.DominantAxis.Height
            aspect.Parent = cardClone
        end

        populateCardInfo(cardClone, cardData, true)

        if i == winnerIndex then
            winnerCardFrame = cardClone
        end

        cardClone.Parent = reelStrip
    end

    layout:ApplyLayout()

    local winnerYOffset = winnerCardFrame.AbsolutePosition.Y - reelStrip.AbsolutePosition.Y
    local cardPixelHeight = winnerCardFrame.AbsoluteSize.Y
    local viewportPixelHeight = slotContainer.AbsoluteSize.Y
    local stepPixels = cardPixelHeight + 12

    local targetY = -winnerYOffset + (viewportPixelHeight / 2) - (cardPixelHeight / 2)

    local lastCardIndex = 0
    local startY = reelStrip.AbsolutePosition.Y

    local conn
    conn = RunService.RenderStepped:Connect(function()
        local currentY = reelStrip.AbsolutePosition.Y
        local distanceTraveled = math.abs(currentY - startY)
        local idx = math.floor(distanceTraveled / stepPixels) + 1
        
        if idx ~= lastCardIndex then
            lastCardIndex = idx
            safePlayTick()
        end
    end)
    table.insert(activeConnections, conn)

    -- Phase 1: Linear stagger velocity
    if delayTime > 0 then
        local fastSpinDistance = stepPixels * (delayTime * 12)
        local fastTweenInfo = TweenInfo.new(delayTime, Enum.EasingStyle.Linear)
        
        local fastTween = TweenService:Create(reelStrip, fastTweenInfo, {
            Position = UDim2.new(0, 0, 0, -fastSpinDistance)
        })
        table.insert(activeTweens, fastTween)
        fastTween:Play()
        
        task.wait(delayTime)

        local fastIdx = table.find(activeTweens, fastTween)
        if fastIdx then table.remove(activeTweens, fastIdx) end
    end

    -- Phase 2: Deceleration curve
    local decelTweenInfo = TweenInfo.new(3.0, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
    local decelTween = TweenService:Create(reelStrip, decelTweenInfo, {
        Position = UDim2.new(0, 0, 0, targetY)
    })
    table.insert(activeTweens, decelTween)

    decelTween:Play()
    decelTween.Completed:Wait()

    conn:Disconnect()
    local connIdx = table.find(activeConnections, conn)
    if connIdx then table.remove(activeConnections, connIdx) end

    local tweenIdx = table.find(activeTweens, decelTween)
    if tweenIdx then table.remove(activeTweens, tweenIdx) end

    -- Zero-Flicker Clean Cutoff Procedure
    if winnerCardFrame and isRolling then
        populateCardInfo(winnerCardFrame, winningCard, false)

        if layout then layout:Destroy() end

        for _, child in ipairs(reelStrip:GetChildren()) do
            if child ~= winnerCardFrame then
                child:Destroy()
            end
        end

        reelStrip.Position = UDim2.new(0, 0, 0, 0)
        reelStrip.Size = UDim2.new(1, 0, 1, 0)

        winnerCardFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        winnerCardFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        winnerCardFrame.Size = UDim2.new(0.95, 0, 0.95, 0)

        local aspect = winnerCardFrame:FindFirstChildOfClass("UIAspectRatioConstraint")
        if not aspect then
            aspect = Instance.new("UIAspectRatioConstraint")
            aspect.AspectRatio = 0.72
            aspect.AspectType = Enum.AspectType.FitWithinMaxSize
            aspect.DominantAxis = Enum.DominantAxis.Height
            aspect.Parent = winnerCardFrame
        end

        bindCardSelection(winnerCardFrame, winningCard, candidateIndex, slotKey)
    end

    return winnerCardFrame
end

DuelGui:GetPropertyChangedSignal("Enabled"):Connect(function()
    if DuelGui.Enabled then
        initializeTeamViews()
    else
        cleanupRollingState()
    end
end)

DuelEvents.RollCardsEvent.OnClientEvent:Connect(function(slotKey, candidates, reelPool)
    table.clear(activeTweens)
    table.clear(activeConnections)
    isRolling = true
    CardSelectionFrame.Visible = true
    
    if slotKey then
        activeSlotKey = slotKey
    end

    task.spawn(function()
        spinSingleSlot(CardSlot1, candidates[1], reelPool, 0.0, 1, activeSlotKey)
    end)
    task.spawn(function()
        spinSingleSlot(CardSlot2, candidates[2], reelPool, 0.5, 2, activeSlotKey)
    end)
    task.spawn(function()
        spinSingleSlot(CardSlot3, candidates[3], reelPool, 1.0, 3, activeSlotKey)
    end)
end)

DuelEvents.OpponentSlotUpdatedEvent.OnClientEvent:Connect(function(slotKey, rarity)
    for _, child in ipairs(OpponentTeamView:GetChildren()) do
        if child:IsA("Frame") then
            local posMatch = (child.Name == slotKey) or (getPositionForSlot(child) == slotKey) or (slotKey:find("CB") and child.Name:find("CB"))
            
            if posMatch then
                local emptyView = child:FindFirstChild("EmptySlotView") or child:FindFirstChild("SelectedSlotView")
                if emptyView then
                    local selectBtn = emptyView:FindFirstChild("SelectPlayerButton", true)
                    local isAlreadySelected = selectBtn and (selectBtn.Text == "SELECTED")
                    
                    if not isAlreadySelected then
                        emptyView.BackgroundColor3 = RarityColors[rarity] or Color3.fromRGB(40, 40, 40)
                        emptyView.BackgroundTransparency = 0
                        
                        if selectBtn and (selectBtn:IsA("TextButton") or selectBtn:IsA("TextLabel")) then
                            selectBtn.Text = "SELECTED"
                            selectBtn.Font = Enum.Font.FredokaOne
                            selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                            selectBtn.TextScaled = true
                            selectBtn.BackgroundTransparency = 1
                        end
                        break
                    end
                end
            end
        end
    end
end)

-- Handle Match Completed: Reveals Opponent OVR, displays 2D Banner, then closes DuelGui
DuelEvents.MatchCompletedEvent.OnClientEvent:Connect(function(myFinalOVR, opponentFinalOVR)
    -- 1. Reveal Opponent OVR
    OpponentOVRValue.Text = tostring(opponentFinalOVR)

    -- 2. Calculate local OVR and determine winner
    local myOVR = tonumber(YourOVRValue.Text) or 0
    local resultTitle = "MATCH DRAW!"
    local resultColor = Color3.fromRGB(255, 215, 0)

    if myOVR > opponentFinalOVR then
        resultTitle = "VICTORY!"
        resultColor = Color3.fromRGB(46, 204, 113)
    elseif myOVR < opponentFinalOVR then
        resultTitle = "DEFEAT!"
        resultColor = Color3.fromRGB(231, 76, 60)
    end

    -- 3. Display 2D Screen Banner
    local banner = DuelMenu:FindFirstChild("MatchResultBanner")
    if not banner then
        banner = Instance.new("TextLabel")
        banner.Name = "MatchResultBanner"
        banner.Size = UDim2.new(1, 0, 0.2, 0)
        banner.Position = UDim2.new(0.5, 0, 0.5, 0)
        banner.AnchorPoint = Vector2.new(0.5, 0.5)
        banner.Font = Enum.Font.FredokaOne
        banner.TextScaled = true
        banner.ZIndex = 5
        
        local stroke = Instance.new("UIStroke")
        stroke.Thickness = 4
        stroke.Color = Color3.fromRGB(0, 0, 0)
        stroke.Parent = banner

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.2, 0)
        corner.Parent = banner
        
        banner.Parent = DuelMenu
    end

    banner.Text = resultTitle .. "\n(" .. myOVR .. " vs " .. opponentFinalOVR .. ")"
    banner.TextColor3 = resultColor
    banner.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    banner.Visible = true

    -- 4. Close DuelGui after 4 seconds so players are transitioned back to field view
    task.delay(4.0, function()
        if banner then banner.Visible = false end
        DuelGui.Enabled = false
        CardSelectionFrame.Visible = false
        cleanupRollingState()
    end)
end)

DuelEvents.ForfeitEvent.OnClientEvent:Connect(function(forfeiterName)
    cleanupRollingState()
    DuelGui.Enabled = false
    CardSelectionFrame.Visible = false
end)

DuelEvents.StartDuelEvent.OnClientEvent:Connect(function(opponentName)
    OpponentTeamLabel.Text = opponentName .. "'s Team"
    initializeTeamViews()
    DuelGui.Enabled = true
end)

local function triggerForfeit()
    cleanupRollingState()
    DuelEvents.ForfeitEvent:FireServer()
    DuelGui.Enabled = false
    CardSelectionFrame.Visible = false
end

ExitButton.MouseButton1Click:Connect(triggerForfeit)

ExitButtonFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        triggerForfeit()
    end
end)

initializeTeamViews()