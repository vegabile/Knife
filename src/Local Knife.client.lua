local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local N = {}
local currentThrowRuntime = nil
local isCooldown = false
local COOLDOWN = 2.6
local MINIMUM_DISTANCE = 75
local device = ""

local function getDevice()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return "mobile"
	else
		return "pc"
	end
end

local function playThrowAnimation(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		warn("Animator not found for character: " .. character.Name)
		return
	end

	local animation = game.ReplicatedStorage.ThrowKnife
	local animationTrack = animator:LoadAnimation(animation)

	animationTrack:Play()

	print("Playing animation on " .. character.Name)
	return animationTrack
end

device = getDevice()

function getCenterScreenTargetPoint()
	local camera = workspace.CurrentCamera
	local viewportCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
	local screenRay = camera:ViewportPointToRay(viewportCenter.X, viewportCenter.Y)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}

	local raycastResult = workspace:Raycast(screenRay.Origin, screenRay.Direction * 1000, raycastParams)

	if raycastResult then
		return raycastResult.Position
	else
		return screenRay.Origin + screenRay.Direction * 1000
	end
end

local function throw(toolHandle : BasePart, isMobile : boolean)
	local ShootRemote : RemoteFunction = toolHandle.Parent:WaitForChild("RequestThrow")
	local character : Model = toolHandle.Parent.Parent
	if not character:IsA("Model") then print("Character is not a model.") return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then print("No humanoid present.") return end
	
	if (currentThrowRuntime) then
		currentThrowRuntime:Disconnect()
		currentThrowRuntime = nil
	end
	
	local targetPosition
	local animTrack : AnimationTrack = playThrowAnimation(character)
	task.wait(1.25)
	if (animTrack) then
		animTrack:Stop()
	end
	if (isMobile) then
		targetPosition = getCenterScreenTargetPoint()
	end
	
	
	local targetPosition = targetPosition or humanoid.TargetPoint
	local orderedName = `{Players.LocalPlayer.Name:lower()}_{tostring(math.random(1, 10000))}`
	local success, reason = ShootRemote:InvokeServer(targetPosition, orderedName)
	if not success then warn("NOT SUCCESS") print(reason) return end
	
	local serverKnife : BasePart = game.Workspace.ThrownKnives:WaitForChild(orderedName)
	
	local throwingHandle : BasePart = toolHandle:Clone()
	throwingHandle.Parent = game.Workspace.ThrownKnives
	throwingHandle.Transparency = 0
	local decal = throwingHandle:FindFirstChildOfClass("Decal")
	if (decal) then
		decal.Transparency = 0
	end
	game:GetService('Debris'):AddItem(throwingHandle, 5)
	
	local direction = -(throwingHandle.Position - targetPosition).Unit
	throwingHandle.CFrame = CFrame.lookAt(throwingHandle.Position, targetPosition)
	
	local floatingForce = Instance.new('BodyForce', throwingHandle)
	floatingForce.force = Vector3.new(0, workspace.Gravity * throwingHandle:GetMass(), 0)
	local spin = Instance.new('BodyAngularVelocity', throwingHandle)
	spin.angularvelocity = throwingHandle.CFrame:vectorToWorldSpace(Vector3.new(-10, 0, 0))
	throwingHandle.AssemblyLinearVelocity = (direction * 72.5)
		
	local function cleanupAndStick(hitPart, hitPosition, hitNormal)
		if currentThrowRuntime then
			currentThrowRuntime:Disconnect()
			currentThrowRuntime = nil
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
	raycastParams.FilterDescendantsInstances = {throwingHandle, character, toolHandle, serverKnife}
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	
	currentThrowRuntime = RunService.PreRender:Connect(function(dt)
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
					print("WAS HIT SOMETHING!", hitPart, position,'WAS ALL IT')

					if (throwingHandle.Position - position).Magnitude > 2.05 then
						return
					end

					local hitModel = hitPart:FindFirstAncestorOfClass("Model")
					local hitHumanoid = hitModel and hitModel:FindFirstChildOfClass("Humanoid")

					print("DETECTION!")
					cleanupAndStick(finalRaycastResult.Instance, finalRaycastResult.Position, finalRaycastResult.Normal)
				end
			end
		end
	end)
	
	return throwingHandle, orderedName
end

local sideHUD = game.Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("SideCombatHUD")
local SideThrowButton : TextButton = sideHUD:WaitForChild("SideThrowButton")
local isMobileThrowing = false
function N.Script(tool : Tool)
	local Handle : BasePart = tool:WaitForChild("Handle")
	local character = tool.Parent
	local storage = tool:WaitForChild("Storage")
		
	local function runAnimation(animName)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local animObj = storage:FindFirstChild(animName)
		if humanoid and animObj then
			local track : AnimationTrack = humanoid:LoadAnimation(animObj)
			track:Play(nil, nil, 1)
			if animName == "Backstab" then
				tool.GripUp = Vector3.new(0, -1, 0)
				task.wait(0.75)
				tool.GripUp = Vector3.new(0, 1, 0)
			end
			task.delay(track.Length + 0.1, function()
				if track then
					track:Stop()
				end
			end)
		end
	end
	
	
	tool.Equipped:Connect(function()
		if (getDevice() == "mobile") then
			sideHUD.Enabled = true
		else
			sideHUD.Enabled = false
		end
	end)
	
	tool.Unequipped:Connect(function()
		sideHUD.Enabled = false
	end)
	
	local lastHit = 0
	UserInputService.InputBegan:Connect(function(input : InputObject, gpe : boolean)
		if gpe then return end

		if (input.KeyCode == Enum.KeyCode.E) then
			if ((tick() - lastHit) < COOLDOWN) then
				print(tick(), lastHit,'was it')
				return
			end
			lastHit = tick()
			
			local throwingHandle, orderedName = throw(Handle)
			if not orderedName then return end
			
			local serverKnife : BasePart = game.Workspace.ThrownKnives:WaitForChild(orderedName)
			if (serverKnife) then
				serverKnife.LocalTransparencyModifier = 1
				if (serverKnife:FindFirstChildOfClass("Decal")) then
					serverKnife:FindFirstChildOfClass("Decal").Transparency = 1
				end
			end
		end
	end)
	
	SideThrowButton.MouseButton1Up:Connect(function()
		local throwingHandle, orderedName = throw(Handle, true)
		local serverKnife : BasePart = game.Workspace.ThrownKnives:WaitForChild(orderedName)
		if (serverKnife) then
			serverKnife.LocalTransparencyModifier = 1
			if (serverKnife:FindFirstChildOfClass("Decal")) then
				serverKnife:FindFirstChildOfClass("Decal").Transparency = 1
			end
		end

		task.wait(COOLDOWN)
	end)	
end

game.Workspace.ThrownKnives.ChildAdded:Connect(function(child)
	if (child.Name:find(Players.LocalPlayer.Name:lower())) then
		child.LocalTransparencyModifier = 1
		if (child:FindFirstChildOfClass("Decal")) then
			child:FindFirstChildOfClass("Decal"):Destroy()
		end
	end
end)

return N