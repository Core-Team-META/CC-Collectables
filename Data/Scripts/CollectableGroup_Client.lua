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
				lastServerUpdate = time(),
				lastLocalUpdate = time(),
				trigger = propTrigger,
				id = totalCoins,
			}
			idToTrigger[totalCoins] = propTrigger
			totalCoins = totalCoins + 1
		end
	end
	recentlyCollected = BF.New(totalCoins)

	propGroupRoot.networkedPropertyChangedEvent:Connect(OnServerUpdate)
	--Events.BroadcastToServer(INIT_EVENT, totalCoins)
	ReliablyBroadcastToServer(INIT_EVENT, totalCoins)
	Task.Spawn(SyncServerDataTask)
end


function SyncServerDataTask()
	while(true) do
		--print("Checking update tasks...")
		if needToReportCollections then
			--print("reporting...", recentlyCollected)
			-- Report to server
			--Events.BroadcastToServer(UPDATE_EVENT, recentlyCollected.bits, recentlyCollected.raw)
			ReliablyBroadcastToServer(UPDATE_EVENT, recentlyCollected.bits, recentlyCollected.raw)
			recentlyCollected:Reset()

			needToReportCollections = false
		end

		-- Fix things to match the server, if they've been changed locally
		-- but the server hasn't validated them after MAX_DESYNC_TIME.
		FixOldData()
		Task.Wait(1)
	end
end







function UpdateFromString()
	local stringData = propGroupRoot:GetCustomProperty(SERVER_DATA_PROPERTY)
	if stringData == nil or stringData == "" then return end

	lastServerUpdateTime = time()

	officialServerData = BF.New(totalCoins, stringData)
	--print("Got string:", stringData)
	--print("Data = ", officialServerData)

	for k,data in pairs(objList) do
		local isActive = officialServerData:Get(data.id)

		-- only update things that haven't changed locally lately.
		if data.lastLocalUpdate + MAX_DESYNC_TIME < time() then
			data.obj.isEnabled = isActive
			data.active = isActive
			data.lastServerUpdate = lastServerUpdateTime
		end
	end
end



function FixOldData()
	if officialServerData == nil then return end
	--print("-----Fixing data.  Server sez:", officialServerData)
	for k,data in pairs(objList) do
		--print(data.id, ":", data.isValidated, data.lastServerUpdate, (data.lastServerUpdate + MAX_DESYNC_TIME) < time())

		-- update only if the last local update is more recent than the server update, but it's
		-- been more than MAX_DESYNC_TIME and we haven't received server validation:
		if data.lastLocalUpdate > data.lastServerUpdate and data.lastLocalUpdate + MAX_DESYNC_TIME < time() then
			local isActive = officialServerData:Get(data.id)
			--print(isActive)
			data.obj.isEnabled = isActive
			data.active = isActive
			data.lastLocalUpdate = time()
			--data.lastServerUpdate = lastServerUpdateTime
		end
	end
end




function OnTriggerHit(trigger, other)
	if other:IsA("Player") then
		local data = objList[trigger]
		if data ~= nil and data.active then
			data.obj.isEnabled = false
			data.active = false
			data.lastLocalUpdate = time()
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
	--print("serverUpdate!")
	if obj == propGroupRoot and property == SERVER_DATA_PROPERTY then
		UpdateFromString()
	end
end


function ReliablyBroadcastToServer(EventName, ...)
	local args = {...}
	Task.Spawn(function()
		local result, error
		local count = 0
		while result ~= BroadcastEventResultCode.SUCCESS do
			result, error = Events.BroadcastToServer(EventName, table.unpack(args))
			Task.Wait(1)
			count = count + 1
			if count == 100 then
				print("Have tried over 100 times to broadcast " .. EventName .. "without success...")
			elseif count == 200 then
				print("200 attempts for " .. EventName .. " ... aborting.")
				return
			end
		end
	end)
end


-- Force an update at start.
UpdateFromString()

Init()



--Events.Connect(serverUpdateEventName, OnServerUpdate)
