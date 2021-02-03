local prop_Bitfields = script:GetCustomProperty("_Bitfields")
local propPickupEffect = script:GetCustomProperty("PickupEffect")
local propGroupRoot = script:GetCustomProperty("GroupRoot"):WaitForObject()
local propAutoRespawnTime = script:GetCustomProperty("AutoRespawnTime")

local SERVER_DATA_PROPERTY = "Contents"

local MAX_DESYNC_TIME = 4	-- How long we'll tolerate a lack of update from server.

local BF = require(prop_Bitfields)
--local collisionEventName = "COLLIDE:" .. script.parent.id
--local serverUpdateEventName = "UPDATE:" .. script.parent.id

local UPDATE_EVENT = propGroupRoot:GetReference().id .. ":UpdateContents"
local INIT_EVENT = propGroupRoot:GetReference().id .. ":Init"


local objList = {}
local idToTrigger = {}
local localPlayer = Game.GetLocalPlayer()
local needToReportCollections = false

local recentlyCollected = nil

local officialServerData = nil
local lastServerUpdateTime = 0
local totalCoins = 0

function Init()
	totalCoins = 0
	for k,v in pairs(propGroupRoot:GetChildren()) do
		if v ~= script then
			local propTrigger = v:GetCustomProperty("Trigger"):WaitForObject()
			propTrigger.beginOverlapEvent:Connect(OnTriggerHit)
			objList[propTrigger] = {
				obj = v,
				active = true,
				lastUpdate = os.time(),
				isValidated = true,
				trigger = propTrigger,
				id = totalCoins,
			}
			idToTrigger[totalCoins] = propTrigger
			totalCoins = totalCoins + 1
		end
	end
	recentlyCollected = BF.New(totalCoins)

	propGroupRoot.networkedPropertyChangedEvent:Connect(OnServerUpdate)
	Events.BroadcastToServer(INIT_EVENT, totalCoins)
	Task.Spawn(SyncServerDataTask)
end


function SyncServerDataTask()
	while(true) do
		--print("Checking update tasks...")
		if needToReportCollections then
			--print("reporting...", recentlyCollected)
			-- Report to server
			Events.BroadcastToServer(UPDATE_EVENT, recentlyCollected.bits, recentlyCollected.raw)
			recentlyCollected:Reset()

			needToReportCollections = false
		end

		-- Check that everything that doesn't agree with server
		-- is recent - reset anything if the server hasn't
		-- corraborated recently.
		FixOldData()
		Task.Wait(2)
	end
end







function UpdateFromString()
	local stringData = propGroupRoot:GetCustomProperty(SERVER_DATA_PROPERTY)
	if stringData == nil or stringData == "" then return end

	lastServerUpdateTime = time()

	officialServerData = BF.New(totalCoins, stringData)
	print("Got string:", stringData)
	print("Data = ", officialServerData)
	for k,data in pairs(objList) do
		local isActive = officialServerData:Get(data.id)
		data.obj.isEnabled = isActive
		data.active = isActive
		data.isValidated = true
		data.lastUpdate = lastServerUpdateTime
	end
end



function FixOldData()
	if officialServerData == nil then return end
	print("-----Fixing data.  Server sez:", officialServerData)
	for k,data in pairs(objList) do
		--print(data.id, ":", data.isValidated, data.lastUpdate, (data.lastUpdate + MAX_DESYNC_TIME) < time())
		if not data.isValidated and (data.lastUpdate + MAX_DESYNC_TIME) < time() then
			local isActive = officialServerData:Get(data.id)
			print(isActive)
			data.obj.isEnabled = isActive
			data.active = isActive
			data.isValidated = true
			--data.lastUpdate = lastServerUpdateTime
		end
	end
end




function OnTriggerHit(trigger, other)
	if other:IsA("Player") then
		local data = objList[trigger]
		if data ~= nil and data.active then
			data.obj.isEnabled = false
			data.active = false
			data.isValidated = false
			if other == localPlayer then
				-- We only count it as collected if it was us!
				recentlyCollected:Set(data.id, true)
			end

			World.SpawnAsset(propPickupEffect, {position = data.obj:GetWorldPosition()})
			needToReportCollections = true
			--print(recentlyCollected)
		end
	end
end




function OnServerUpdate(obj, property)
	print("serverUpdate!")
	if obj == propGroupRoot and property == SERVER_DATA_PROPERTY then
		UpdateFromString()
	end
end

-- Force an update at start.
UpdateFromString()

Init()



--Events.Connect(serverUpdateEventName, OnServerUpdate)
