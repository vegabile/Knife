local N = {}
local specificAngles = {
	["heatknife"] = Vector3.new(-55.476, -9.132, -172.477);
	["tidesknife"] = Vector3.new(31.864, -180, 174.11)
}

function N.Script(tool : Tool)
	local hipAccessory = nil

	local function knifeToSide()
		local player = tool.Parent and tool.Parent.Parent
		if not (player and player:IsA("Player")) then
			return
		end

		local character = player.Character or player.CharacterAdded:Wait()
		if not character then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			warn("Humanoid not found for player " .. player.Name)
			return
		end

		local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
		local toolHandle = tool:FindFirstChild("Handle")

		if not (humanoidRootPart and toolHandle and toolHandle:IsA("BasePart")) then
			return
		end

		character:WaitForChild("LowerTorso"):WaitForChild("KnifePlaceAttachment")

		if hipAccessory then
			hipAccessory:Destroy()
			hipAccessory = nil
		end
		
		for _, child in ipairs(character:GetDescendants()) do
			if (child.Name == "HipKnifeAccessory") and (child:IsA("Accessory")) then
				child:Destroy()
			end
		end

		local newAccessory = Instance.new("Accessory")
		newAccessory.Name = "HipKnifeAccessory"
		newAccessory.AccessoryType = Enum.AccessoryType.Waist


		local accessoryHandle = toolHandle:Clone()
		accessoryHandle.Name = "Handle"
		accessoryHandle.CanCollide = false
		accessoryHandle.Anchored = false
		
		local knifeName : StringValue = tool:FindFirstChild("knifeName")
		local toolName = ""
		if (knifeName) then
			toolName = knifeName.Value
		end
		
		print(toolName,'was it.',specificAngles, specificAngles[toolName])
		accessoryHandle.Rotation = (specificAngles[toolName]) or Vector3.new(-60, 180, 175)

		local KnifePlaceAttachment = Instance.new("Attachment")
		KnifePlaceAttachment.Name = "KnifePlaceAttachment"
		KnifePlaceAttachment.Parent = accessoryHandle
		
		print(toolName,'was the tool name!')
		KnifePlaceAttachment.Orientation = (specificAngles[toolName]) or Vector3.new(-60, 180, 175)

		for _, descendant in ipairs(accessoryHandle:GetDescendants()) do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant.Disabled = true
			elseif descendant:IsA("Weld") or descendant:IsA("WeldConstraint") or descendant:IsA("Motor6D") then
				descendant:Destroy()
			end
		end
		accessoryHandle.Parent = newAccessory

		humanoid:AddAccessory(newAccessory)
		hipAccessory = newAccessory
	end

	knifeToSide()
	tool.Equipped:Connect(function()
		if hipAccessory then
			hipAccessory:Destroy()
			hipAccessory = nil
		end
	end)

	tool.Unequipped:Connect(function()
		knifeToSide()
	end)
end

return N