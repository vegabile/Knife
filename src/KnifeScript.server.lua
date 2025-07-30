local N = {}

local RenderKnifeEvent = game.ReplicatedStorage.Remotes.RenderKnifeEvent

local RunService = game:GetService('RunService')
local currentThrowRuntime = nil

local KillFeedRemote = game.ReplicatedStorage.Remotes.KillFeedRemote

local COOLDOWN = 2.6
local isSlashing = false

local lastKillTime = 0
local killCooldown = 1.2
local function killTarget(killer : Player, target : Player, humanoid : Humanoid)
	if tick() - lastKillTime < killCooldown then
		return
	end

	if not (target.Team and target.Team.Name:lower() == "hider") then
		return
	end

	lastKillTime = tick()

	humanoid.Health = 0

	KillFeedRemote:FireAllClients(killer, "Eliminate", target)
	print("FIRED TO ALL FROM SERVER POV!")
end

local throwCooldown = false
local lastThrow = 0
local function throw(toolHandle : BasePart, targetPosition : Vector3, orderedName : string)
	local character : Model = toolHandle.Parent.Parent
	if not character:IsA("Model") then return false, "Character not a model." end
	if ((tick() - lastThrow) < COOLDOWN) then return false end

	lastThrow = tick()

	local heartbeatConnection = nil

	local throwingHandle : BasePart = toolHandle:Clone()
	throwingHandle.Parent = game.Workspace.ThrownKnives
	throwingHandle.Name = orderedName
	game:GetService('Debris'):AddItem(throwingHandle, 5)

        local direction = -(throwingHandle.Position - targetPosition).Unit
        throwingHandle.CFrame = CFrame.lookAt(throwingHandle.Position, targetPosition)

	local floatingForce = Instance.new('BodyForce', throwingHandle)
	floatingForce.force = Vector3.new(0, workspace.Gravity * throwingHandle:GetMass(), 0)
	local spin = Instance.new('BodyAngularVelocity', throwingHandle)
	spin.angularvelocity = throwingHandle.CFrame:vectorToWorldSpace(Vector3.new(-10, 0, 0))
        throwingHandle.AssemblyLinearVelocity = (direction * 72.5)

        throwingHandle.Transparency = 1
        if (throwingHandle:FindFirstChildOfClass("Decal")) then
                throwingHandle:FindFirstChildOfClass("Decal").Transparency = 1
        end

        RenderKnifeEvent:FireAllClients(targetPosition, orderedName)

	toolHandle.Transparency = 1
	if (toolHandle:FindFirstChildOfClass("Decal")) then
		toolHandle:FindFirstChildOfClass("Decal").Transparency = 1
	end

	local function cleanupAndStick(hitPart, hitPosition, hitNormal)
		if heartbeatConnection then
			heartbeatConnection:Disconnect()
			heartbeatConnection = nil
		end

		if not throwingHandle or not throwingHandle.Parent then return end

		if floatingForce and floatingForce.Parent then floatingForce:Destroy() end
		if spin and spin.Parent then spin:Destroy() end

		throwingHandle.AssemblyLinearVelocity = Vector3.zero
		throwingHandle.AssemblyAngularVelocity = Vector3.zero
		throwingHandle.CanTouch = false

		if hitPart and hitPart.Parent and hitPosition and hitNormal then
			local STAB_DEPTH = 1.0
			local lookAtPosition = hitPosition + hitNormal
			local stabPosition = hitPosition - hitNormal * (throwingHandle.Size.Z / 2 - STAB_DEPTH)
			local baseCFrame = CFrame.lookAt(stabPosition, lookAtPosition)
			local rotation = CFrame.Angles(math.rad(45), 0, 0)
			throwingHandle.CFrame = baseCFrame * rotation
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = throwingHandle
			weld.Part1 = hitPart
			weld.Parent = throwingHandle
		elseif hitPart and hitPart.Parent then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = throwingHandle
			weld.Part1 = hitPart
			weld.Parent = throwingHandle
		end
	end

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {throwingHandle, character, toolHandle}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if not throwingHandle.Parent then
			if heartbeatConnection then
				heartbeatConnection:Disconnect()
				heartbeatConnection = nil
			end
			return
		end

		for _, raycastPoint : Attachment in ipairs(throwingHandle:GetChildren()) do
			if (raycastPoint:IsA("Attachment") and raycastPoint.Name == "DmgPoint") then
				local origin = raycastPoint.WorldPosition
				local velocity = throwingHandle.AssemblyLinearVelocity
				local finalRaycastResult = nil
				local predictiveRayResult = workspace:Raycast(origin, velocity.Unit * 3.5, raycastParams)

				if predictiveRayResult then
					finalRaycastResult = predictiveRayResult
				else
					local rayLength = velocity.Magnitude * dt
					if rayLength >= 0.1 then
						local mainRaycastResult = workspace:Raycast(origin, velocity.Unit * rayLength, raycastParams)
						if mainRaycastResult then
							finalRaycastResult = mainRaycastResult
						end
					end
				end

				if finalRaycastResult then
					local hitPart = finalRaycastResult.Instance
					local position = finalRaycastResult.Position

					if (throwingHandle.Position - position).Magnitude > 2.05 then
						return
					end

					if not hitPart then return end

					local hitModel = hitPart:FindFirstAncestorOfClass("Model")
					local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")

					if hitHumanoid and hitHumanoid.Health > 0 then
						local hitPlayer = game.Players:GetPlayerFromCharacter(hitModel)
						if not hitPlayer then return end

						local player = game.Players:GetPlayerFromCharacter(character)

						killTarget(player, hitPlayer, hitHumanoid)
					end

					cleanupAndStick(finalRaycastResult.Instance, finalRaycastResult.Position, finalRaycastResult.Normal)
				end
			end
		end
	end)

	task.delay(COOLDOWN, function()
		throwCooldown = false
		toolHandle.Transparency = 0
		if (toolHandle:FindFirstChildOfClass("Decal")) then
			toolHandle:FindFirstChildOfClass("Decal").Transparency = 0
		end		
	end)

	return true	
end

local canSlash = true
local COOLDOWN = 0.75
function N.Script(tool)
	local ShootRemote : RemoteFunction = tool:WaitForChild("RequestThrow")
	local Handle : BasePart = tool:WaitForChild("Handle")
	
	ShootRemote.OnServerInvoke = function(player : Player, targetPosition, orderedName)
		return throw(Handle, targetPosition, orderedName)
	end
	
	local lastSlash = 0
	local oldTrack = nil
	tool.Activated:Connect(function()
		if (tick() - lastSlash < COOLDOWN) then
			return
		end
		
		print("SLASHING!")
		
		canSlash = false
		local character : Model = tool.Parent
		local animations = tool:WaitForChild("Animations")
		local animList = animations:GetChildren()
		if #animList == 0 then
			print("None.")
			return
		end
		
		lastSlash = tick()
		
		
		print(character)
		local selectedAnimation = animList[math.random(1, #animList)]
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		isSlashing = true
		local track = humanoid:LoadAnimation(selectedAnimation)
		track.Looped = false
		oldTrack = track
		
		track:Play()
	end)
	
	Handle.Touched:Connect(function(hit : BasePart)
		local Char = tool.Parent
		local Player = game:GetService('Players'):GetPlayerFromCharacter(Char)
		
		local char2 = hit.Parent
		local Player2 = game:GetService('Players'):GetPlayerFromCharacter(char2)
		
		if (Player2) and (Player) and (Player2 ~= Player) and (isSlashing == true) then
			killTarget(Player, Player2, char2:FindFirstChildOfClass("Humanoid"))
		end
	end)
	
	tool.Destroying:Connect(function()
		if (oldTrack) then
			oldTrack:Stop()
			oldTrack = nil
		end
	end)
end

return N