local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- 1. Setup Remote Event
local exitQueueEvent = ReplicatedStorage:FindFirstChild("ExitQueueEvent")
if not exitQueueEvent then
	exitQueueEvent = Instance.new("RemoteEvent")
	exitQueueEvent.Name = "ExitQueueEvent"
	exitQueueEvent.Parent = ReplicatedStorage
end

-- 2. State tracking
local fieldsState = {} -- [fieldIndex] = { player1 = Player, player2 = Player, countdownActive = boolean }
local playerCooldowns = {} -- [Player] = clockTime
local COOLDOWN_DURATION = 2.0
local playerOriginalStats = {} -- [Player] = { WalkSpeed = number, JumpPower = number, UseJumpPower = boolean, JumpHeight = number }

-- Helper to check if a player is already queued
local function isPlayerQueued(player)
	for i = 1, 8 do
		local state = fieldsState[i]
		if state and (state.player1 == player or state.player2 == player) then
			return true
		end
	end
	return false
end

-- Helper to create or get BillboardGui label that faces the player
local function getOrCreateLabel(anchorPart, guiName)
	if not anchorPart then return nil end
	
	-- Cleanup old SurfaceGuis if any exist
	for _, child in ipairs(anchorPart:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	
	local billboard = anchorPart:FindFirstChild(guiName)
	if not billboard then
		billboard = Instance.new("BillboardGui")
		billboard.Name = guiName
		billboard.Size = UDim2.new(12, 0, 4, 0) -- 50% larger readable size
		billboard.AlwaysOnTop = true
		billboard.StudsOffset = Vector3.new(0, 0, 0) -- Center directly on the anchor block
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

-- Helper to update anchor text on the camera-facing BillboardGui
local function updateAnchorText(anchorPart, text, color)
	local label = getOrCreateLabel(anchorPart, "StatusBillboard")
	if label then
		label.Text = text
		if color then
			label.TextColor3 = color
		end
	end
end

-- Helper to release a player
local releasePlayer -- forward declaration

-- Helper to unlock player character and reset UI
local function unlockPlayer(player, spotName, fieldIndex)
	playerCooldowns[player] = os.clock() + COOLDOWN_DURATION

	local playerGui = player:FindFirstChild("PlayerGui")
	if playerGui then
		local exitGui = playerGui:FindFirstChild("ExitQueue")
		if exitGui then
			exitGui.Enabled = false
		end
		local duelGui = playerGui:FindFirstChild("DuelGui")
		if duelGui then
			duelGui.Enabled = false
		end
	end

	local character = player.Character
	if character then
		-- Restore original speed/jump parameters
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
					-- Align player rotation with the spot exit direction, fully upright
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

-- Update labels based on queue status
local function updateFieldLabels(fieldIndex)
	local state = fieldsState[fieldIndex]
	local field = workspace:FindFirstChild("Soccer Field " .. fieldIndex)
	if not field then return end

	local statusAnchor = field:FindFirstChild("StatusAnchor", true)
	local countdownAnchor = field:FindFirstChild("CountdownAnchor", true)

	if state.countdownActive then return end

	local p1 = state.player1
	local p2 = state.player2

	if not p1 and not p2 then
		updateAnchorText(statusAnchor, "", Color3.fromRGB(255, 255, 255))
		updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
	elseif p1 and p2 then
		-- Triggers countdown
		task.spawn(function()
			if state.countdownActive then return end
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

			-- Enable DuelGui and disable ExitQueue
			local players = {state.player1, state.player2}
			for _, p in ipairs(players) do
				local pGui = p:FindFirstChild("PlayerGui")
				if pGui then
					local duelGui = pGui:FindFirstChild("DuelGui")
					if duelGui then
						duelGui.Enabled = true
					end
					local exitGui = pGui:FindFirstChild("ExitQueue")
					if exitGui then
						exitGui.Enabled = false
					end
				end
			end

			updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
			updateAnchorText(statusAnchor, "Match Active!", Color3.fromRGB(0, 255, 0))
		end)
	else
		updateAnchorText(statusAnchor, "Waiting for Opponent...", Color3.fromRGB(255, 255, 255))
		updateAnchorText(countdownAnchor, "", Color3.fromRGB(255, 255, 255))
	end
end

-- Lock player character into spot
local function lockPlayer(player, spotModel, spotName, fieldIndex)
	local character = player.Character
	if not character then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then return end

	local currentTime = os.clock()
	if playerCooldowns[player] and currentTime < playerCooldowns[player] then
		return
	end

	local state = fieldsState[fieldIndex]
	if spotName == "Player 1 Spot" then
		state.player1 = player
	else
		state.player2 = player
	end

	-- Store original speed/jump parameters and set to 0 to prevent animations triggering
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

	-- Teleport player to the center of the spot, aligned perfectly upright and facing forward
	local centerCFrame, size = spotModel:GetBoundingBox()
	local uprightPosition = Vector3.new(centerCFrame.Position.X, centerCFrame.Position.Y - size.Y / 2 + 3.0, centerCFrame.Position.Z)
	local look = centerCFrame.LookVector
	local uprightCFrame = CFrame.lookAt(uprightPosition, uprightPosition + Vector3.new(look.X, 0, look.Z))
	
	rootPart.CFrame = uprightCFrame
	
	-- Zero out physical velocities
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	-- Stop all playing animation tracks so player stands still in default idle
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
		if exitGui then
			exitGui.Enabled = true
		end
	end

	local diedConnection
	diedConnection = humanoid.Died:Connect(function()
		diedConnection:Disconnect()
		releasePlayer(player)
	end)
end

releasePlayer = function(player)
	for i = 1, 8 do
		local state = fieldsState[i]
		if state then
			if state.player1 == player then
				state.player1 = nil
				state.countdownActive = false
				unlockPlayer(player, "Player 1 Spot", i)
				updateFieldLabels(i)
				return
			elseif state.player2 == player then
				state.player2 = nil
				state.countdownActive = false
				unlockPlayer(player, "Player 2 Spot", i)
				updateFieldLabels(i)
				return
			end
		end
	end
end

-- 3. Initialize join handlers
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local playerGui = player:WaitForChild("PlayerGui", 10)
		if playerGui then
			local hud = playerGui:WaitForChild("HUD", 5)
			if hud then
				hud.Enabled = true
			end
			local exitGui = playerGui:WaitForChild("ExitQueue", 5)
			if exitGui then
				exitGui.Enabled = false
			end
		end
	end)
end)

-- 4. Setup touched connections and field states
local function setupSpotConnections()
	for i = 1, 8 do
		fieldsState[i] = {
			player1 = nil,
			player2 = nil,
			countdownActive = false
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
			
			-- Initialize labels on start
			updateFieldLabels(i)
		end
	end
end

task.spawn(setupSpotConnections)

-- 5. Listen for exits
exitQueueEvent.OnServerEvent:Connect(function(player)
	releasePlayer(player)
end)

Players.PlayerRemoving:Connect(function(player)
	releasePlayer(player)
	playerCooldowns[player] = nil
end)

