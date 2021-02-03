local prop_Bitfields = script:GetCustomProperty("_Bitfields")
local propClientRoot = script:GetCustomProperty("ClientRoot"):WaitForObject()

local propResource = script.parent:GetCustomProperty("Resource")
local propResourceAmount = script.parent:GetCustomProperty("ResourceAmount")

local SERVER_DATA_PROPERTY = "Contents"

local BF = require(prop_Bitfields)


local collectableData = nil

function InitContents(player, itemCount)
	print("Initting with ", itemCount, "items!")
	if collectableData ~= nil then return end

	collectableData = BF.New(itemCount)
	collectableData:Reset(true)

	UpdateCurrentStringData()
end


function UpdateContents(player, bits, dataString)
	local collected = BF.New(bits, dataString)
	print("Received collected: ", collected)
	local needToUpdate = false

	for i = 0, collectableData.bits - 1 do
		if collected:Get(i) then
			if collectableData:Get(i) then
				collectableData:Set(i, false)
				player:AddResource(propResource, propResourceAmount)
				needToUpdate = true
				print("Collected!")
			else
				warn("!!!! Tried to collect an id that wasn't there:" .. tostring(i) .. ":" .. player.name)
			end
		end
	end
	if needToUpdate then
		UpdateCurrentStringData()
	end


end

function UpdateCurrentStringData()


	if collectableData ~= nil then
		--collectableData:Reset(true)
		print("sending new data!------------", collectableData)
		propClientRoot:SetNetworkedCustomProperty(SERVER_DATA_PROPERTY, collectableData.raw)
	else
		warn("Somehow got to update string data without any data?")
	end

end



print("Registering")
Events.ConnectForPlayer(propClientRoot:GetReference().id .. ":UpdateContents", UpdateContents)
Events.ConnectForPlayer(propClientRoot:GetReference().id .. ":Init", InitContents)