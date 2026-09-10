local Keys = {
	["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
	["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
	["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
	["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
	["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
	["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
	["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
	["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
	["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX = nil
local isStaff = false
local group 
local isMenuOpen = false
local MenuPosition = "right"
local SeachedPlayersMenu
local Config
local DonateCarMenu
local TimeStampsMenu
local getRentMenu
local mainMenu 
local Items
local GiveCarID

local staffchatStatus = true


local rightPosition = {x = math.floor(1350), y = math.floor(100)}
local leftPosition = {x = math.floor(0), y = math.floor(100)}
local menuPosition = {x = math.floor(0), y = math.floor(200)}

if MenuPosition == "left" then
    menuPosition = leftPosition
elseif MenuPosition == "right" then
    menuPosition = rightPosition
end

local menuPool = NativeUI.CreatePool()
local freeCam = false
local freeCamObj
local w, h = GetActiveScreenResolution()
local _ScrW = w
local _ScrH = h

--global vars




function KeyboardInput(TextEntry, ExampleText, MaxStringLenght)

	--[[ -- TextEntry		-->	The Text above the typing field in the black square
	-- ExampleText		-->	An Example Text, what it should say in the typing field
	-- MaxStringLenght	-->	Maximum String Lenght

	AddTextEntry('FMMC_KEY_TIP1', TextEntry) --Sets the Text above the typing field in the black square
	DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP1", "", ExampleText, "", "", "", MaxStringLenght) --Actually calls the Keyboard Input
	blockinput = true --Blocks new input while typing if **blockinput** is used

	while UpdateOnscreenKeyboard() ~= 1 and UpdateOnscreenKeyboard() ~= 2 do --While typing is not aborted and not finished, this loop waits
		Citizen.Wait(0)
	end
		
	if UpdateOnscreenKeyboard() ~= 2 then
		local result = GetOnscreenKeyboardResult() --Gets the result of the typing
		Citizen.Wait(500) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		blockinput = false --This unblocks new Input when typing is done
		return result --Returns the result
	else
		Citizen.Wait(500) --Little Time Delay, so the Keyboard won't open again if you press enter to finish the typing
		blockinput = false --This unblocks new Input when typing is done
	end ]]

	local answer
	ESX.UI.Menu.Open(
		'dialog', GetCurrentResourceName(), TextEntry,
		{
			title = TextEntry,
		},
	function (data, menu)
		menu.close()
		if data.value ~= nil then
			answer = tostring(data.value)
		else
			answer = "0"
		end
	end,
	function (data, menu)
		menu.close()
		answer = "0"
	end)

	while answer == nil do Wait(100) end

	return answer
end


RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	ESX.TriggerServerCallback('esx_LigmaMenu:getGroup',function(answer)
		group = answer
	end)
end)



Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(0)
	end
end)

function CheckPermissions(action)
	local acessTable = {}
	local minAcessGroup = "disabled"
	if Config == nil then
		return false
	end
	if action == 'GiveCarToGarage' then
		minAcessGroup = Config.GiveCarToGarage 
	elseif action == 'SpawnDonateCars' then
		minAcessGroup = Config.SpawnDonateCars
	elseif action == 'RepairVehicle' then
		minAcessGroup = Config.RepairVehicle
	elseif action == 'DeleteVehicle' then
		minAcessGroup = Config.DeleteVehicle
	elseif action == 'SetMeDriver' then
		minAcessGroup = Config.SetMeDriver
	elseif action == 'GiveBlackMoney' then
		minAcessGroup = Config.GiveBlackMoney
	elseif action == 'SendToJail' then
		minAcessGroup = Config.SendToJail
	elseif action == 'RemoveJail' then
		minAcessGroup = Config.RemoveJail
	elseif action == 'SetPassenger' then
		minAcessGroup = Config.SetPassenger
	elseif action == 'Ban' then
		minAcessGroup = Config.Ban
	elseif action == 'UnBan' then
		minAcessGroup = Config.UnBan
	elseif action == 'GetRentedHomes' then
		minAcessGroup = Config.GetRentedHomes
	elseif action == 'GetHomeItems' then
		minAcessGroup = Config.GetHomeItems
	elseif action == 'GetHomeItemsOff' then
		minAcessGroup = Config.GetHomeItemsOff
	elseif action == 'GetPlayerBillings' then
		minAcessGroup = Config.GetPlayerBillings
	elseif action == 'GetInventoryHistory' then
		minAcessGroup = Config.GetInventoryHistory
	elseif action == 'ManageGarageVehicles' then
		minAcessGroup = Config.ManageGarageVehicles
	elseif action == 'SendToCommunityService' then
		minAcessGroup = Config.SendToCommunityService
	elseif action == 'RemoveCommunityService' then
		minAcessGroup = Config.RemoveCommunityService
	elseif action == 'OpenMenu' then
		minAcessGroup = Config.OpenMenu
	elseif action == 'StaffChat' then
		minAcessGroup = Config.StaffChat
	elseif action == 'DrawTalking' then
		minAcessGroup = Config.DrawTalking
	elseif action == 'vMenu' then
		minAcessGroup = Config.vMenu
	elseif action == 'Teleport' then
		minAcessGroup = Config.Teleport
	elseif action == 'SetJob' then
		minAcessGroup = Config.SetJob
	elseif action == 'SetGroup' then
		minAcessGroup = Config.SetGroup
	elseif action == 'Priority' then
		minAcessGroup = Config.Priority
	elseif action == 'ClonePed' then
		minAcessGroup = Config.ClonePed
	elseif action == 'ViewStaff' then
		minAcessGroup = Config.ViewStaff
	elseif action == 'Freecam' then
		minAcessGroup = Config.Freecam
	end
	local foundGroup = false
	for k,v in pairs(Config.groups) do
		if v == minAcessGroup then
			foundGroup = true
		end
		if foundGroup then
			table.insert(acessTable,v)
		end
	end
	for k,v in pairs(acessTable) do
		if group == v then
			return true
		end
	end
	return false
end

function SetVehicleMaxMods(vehicle)

	local props = {
	  modEngine       = math.floor(3),
	  modBrakes       = math.floor(2),
	  modTransmission = math.floor(2),
	  modSuspension   = math.floor(3),
	  modTurbo        = true,
	}
  
	ESX.Game.SetVehicleProperties(vehicle, props)
	SetVehicleColours(vehicle,math.floor(0),math.floor(0))
	SetVehicleExtraColours(vehicle,math.floor(0),math.floor(0))
end

local function ClonePedlol(target)
	local ped = GetPlayerPed(target)
	local me = PlayerPedId()
	
	hat = GetPedPropIndex(ped, math.floor(0))
	hat_texture = GetPedPropTextureIndex(ped, math.floor(0))
	
	glasses = GetPedPropIndex(ped, math.floor(1))
	glasses_texture = GetPedPropTextureIndex(ped, math.floor(1))
	
	ear = GetPedPropIndex(ped, math.floor(2))
	ear_texture = GetPedPropTextureIndex(ped, math.floor(2))
	
	watch = GetPedPropIndex(ped, math.floor(6))
	watch_texture = GetPedPropTextureIndex(ped, math.floor(6))
	
	wrist = GetPedPropIndex(ped, math.floor(7))
	wrist_texture = GetPedPropTextureIndex(ped, math.floor(7))
	
	head_drawable = GetPedDrawableVariation(ped, math.floor(0))
	head_palette = GetPedPaletteVariation(ped, math.floor(0))
	head_texture = GetPedTextureVariation(ped, math.floor(0))
	
	beard_drawable = GetPedDrawableVariation(ped, math.floor(1))
	beard_palette = GetPedPaletteVariation(ped, math.floor(1))
	beard_texture = GetPedTextureVariation(ped, math.floor(1))
	
	hair_drawable = GetPedDrawableVariation(ped, math.floor(2))
	hair_palette = GetPedPaletteVariation(ped, math.floor(2))
	hair_texture = GetPedTextureVariation(ped, math.floor(2))
	
	torso_drawable = GetPedDrawableVariation(ped, math.floor(3))
	torso_palette = GetPedPaletteVariation(ped, math.floor(3))
	torso_texture = GetPedTextureVariation(ped, math.floor(3))
	
	legs_drawable = GetPedDrawableVariation(ped, math.floor(4))
	legs_palette = GetPedPaletteVariation(ped, math.floor(4))
	legs_texture = GetPedTextureVariation(ped, math.floor(4))
	
	hands_drawable = GetPedDrawableVariation(ped, math.floor(5))
	hands_palette = GetPedPaletteVariation(ped, math.floor(5))
	hands_texture = GetPedTextureVariation(ped, math.floor(5))
	
	foot_drawable = GetPedDrawableVariation(ped, math.floor(6))
	foot_palette = GetPedPaletteVariation(ped, math.floor(6))
	foot_texture = GetPedTextureVariation(ped, math.floor(6))
	
	acc1_drawable = GetPedDrawableVariation(ped, math.floor(7))
	acc1_palette = GetPedPaletteVariation(ped, math.floor(7))
	acc1_texture = GetPedTextureVariation(ped, math.floor(7))
	
	acc2_drawable = GetPedDrawableVariation(ped, math.floor(8))
	acc2_palette = GetPedPaletteVariation(ped, math.floor(8))
	acc2_texture = GetPedTextureVariation(ped, math.floor(8))
	
	acc3_drawable = GetPedDrawableVariation(ped, math.floor(9))
	acc3_palette = GetPedPaletteVariation(ped, math.floor(9))
	acc3_texture = GetPedTextureVariation(ped, math.floor(9))
	
	mask_drawable = GetPedDrawableVariation(ped, math.floor(10))
	mask_palette = GetPedPaletteVariation(ped, math.floor(10))
	mask_texture = GetPedTextureVariation(ped, math.floor(10))
	
	aux_drawable = GetPedDrawableVariation(ped, math.floor(11))
	aux_palette = GetPedPaletteVariation(ped, math.floor(11)) 	
	aux_texture = GetPedTextureVariation(ped, math.floor(11))

	SetPedPropIndex(me, math.floor(0), hat, hat_texture, math.floor(1))
	SetPedPropIndex(me, math.floor(1), glasses, glasses_texture, math.floor(1))
	SetPedPropIndex(me, math.floor(2), ear, ear_texture,math.floor(1))
	SetPedPropIndex(me, math.floor(6), watch, watch_texture, math.floor(1))
	SetPedPropIndex(me, math.floor(7), wrist, wrist_texture, math.floor(1))
	
	SetPedComponentVariation(me, math.floor(0), head_drawable, head_texture, head_palette)
	SetPedComponentVariation(me, math.floor(1), beard_drawable, beard_texture, beard_palette)
	SetPedComponentVariation(me, math.floor(2), hair_drawable, hair_texture, hair_palette)
	SetPedComponentVariation(me, math.floor(3), torso_drawable, torso_texture, torso_palette)
	SetPedComponentVariation(me, math.floor(4), legs_drawable, legs_texture, legs_palette)
	SetPedComponentVariation(me, math.floor(5), hands_drawable, hands_texture, hands_palette)
	SetPedComponentVariation(me, math.floor(6), foot_drawable, foot_texture, foot_palette)
	SetPedComponentVariation(me, math.floor(7), acc1_drawable, acc1_texture, acc1_palette)
	SetPedComponentVariation(me, math.floor(8), acc2_drawable, acc2_texture, acc2_palette)
	SetPedComponentVariation(me, math.floor(9), acc3_drawable, acc3_texture, acc3_palette)
	SetPedComponentVariation(me, math.floor(10), mask_drawable, mask_texture, mask_palette)
	SetPedComponentVariation(me, math.floor(11), aux_drawable, aux_texture, aux_palette)
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)
		if NetworkIsSessionStarted() then
			TriggerServerEvent("Queue:playerActivated")
			TriggerServerEvent('hardcap:playerActivated')
			return
		end
	end
end)

RegisterNetEvent('esx_LigmaMenu:staffChat')
AddEventHandler('esx_LigmaMenu:staffChat',function(Id,sender,msg)

	if (CheckPermissions('StaffChat')) and staffchatStatus then
		TriggerEvent('chat:addMessage', {
			template = '<div style="display:inline-block;width: calc(10%-50px); padding: 6px; margin: 0.1px; background-color: rgba(47, 67, 82, 1); border-top-right-radius: 17px; border-bottom-right-radius: 17px; border-top-left-radius: 17px;"><font color="#ff4a4a"><b>{0}</b></font> {1}</div>',
			args = {Id, " " .. sender .. ": ".. msg }
		})
	end
end)

CreateThread(function()
	Citizen.Wait(3000)
	ESX.TriggerServerCallback('esx_LigmaMenu:getGroup',function(answer)
		group = answer
	end)

end)

RegisterNetEvent('esx_LigmaMenu:conf')
AddEventHandler('esx_LigmaMenu:conf',function(val)
	Config = val
end)

RegisterNetEvent('esx_LigmaMenu:setGroup')
AddEventHandler('esx_LigmaMenu:setGroup',function(val)
	group = val
end)

RegisterNetEvent('esx_LigmaMenu:staffchatCStatus')
AddEventHandler('esx_LigmaMenu:staffchatCStatus',function(val)

	if val == "on" then
		staffchatStatus = true
	elseif val == "off" then
		staffchatStatus = false
	end

end)

RegisterNetEvent('esx_LigmaMenu:printBillings')
AddEventHandler('esx_LigmaMenu:printBillings',function(data)
	menuPool:CloseAllMenus()	
	local itemChosen
	local bills = {}
	for i = 1, #data do
		table.insert(bills,{label = "Name:  "..data[i].label.."["..data[i].amount.."]      Sender: "..data[i].name, value = data[i].id})
	end
	ESX.UI.Menu.CloseAll()
	billMenu = ESX.UI.Menu.Open(
	'default', GetCurrentResourceName(), 'Bills',
      {
        title    = 'Bills',
        align    = 'center',
        elements = bills
      },
	  function(data, menu)
		itemChosen = data.current.value
		menu.close()
		local Confirmation = {}
		table.insert(Confirmation,{label = "No", value = "no"})
		table.insert(Confirmation,{label = "Yes", value = "yes"})
			confirmMenu = ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'ConfirmMenu',
			{
				title    = 'Delete?',
				align    = 'center',
				elements = Confirmation
			},
			function(data, menu)
				menu.close()
				TriggerServerEvent('esx_LigmaMenu:deleteBill' , itemChosen)
			end,
			function(data,menu)
				menu.close()
		end)
	end,
	function(data,menu)
		menu.close()
	end)
end)

RegisterNetEvent('esx_LigmaMenu:printCars')
AddEventHandler('esx_LigmaMenu:printCars',function(data)
	menuPool:CloseAllMenus()	
	local PLATE
	local NAME
	local cars = {}
	for i = 1, #data do
		table.insert(cars,{label = "Name:  "..tostring(GetDisplayNameFromVehicleModel(tonumber(data[i].model))).."      Plate: "..data[i].plate, value = data[i].plate})
	end
	ESX.UI.Menu.CloseAll()
	carMenu = ESX.UI.Menu.Open(
	'default', GetCurrentResourceName(), 'Cars',
      {
        title    = 'Cars',
        align    = 'center',
        elements = cars
      },
	  function(data, menu)
		menu.close()
		PLATE = data.current.value
		NAME = data.current.label
		local Options = {}
		table.insert(Options,{label = "Change Plate", value = "plate"})
		table.insert(Options,{label = "Delete This", value = "delete"})
			carMenu = ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'Cars',
			{
				title    = 'Options',
				align    = 'center',
				elements = Options
			},
			function(data, menu)
				menu.close()
				if data.current.value == 'plate' then
					local plateText =  KeyboardInput("Add Plate Text","",math.floor(4))
					if plateText ~= nil and plateText ~= "" then
						plateText = string.upper(plateText)
						TriggerServerEvent('esx_LigmaMenu:updatePlate' , PLATE,plateText)
						ESX.ShowNotification("~g~Plate Changed to "..plateText)
					else
						ESX.ShowNotification("~r~Text Too Small")
					end
				else
					local prompt = {}
					table.insert(prompt,{label = "no" ,value = "no"})
					table.insert(prompt,{label = "yes" ,value = "yes"})

					carMenu = ESX.UI.Menu.Open(
					'default', GetCurrentResourceName(), 'Delete',
					{
						title    = 'Delete?',
						align    = 'center',
						elements = prompt
					},
					function(data, menu)
						menu.close()
						if data.current.value == "yes" then
							TriggerServerEvent('esx_LigmaMenu:deletecar' , PLATE)
							ESX.ShowNotification("~g~Vehicle Deleted From Database")
						end
					end,
					function (data, menu)
						menu.close()
					end
					)
				end
			end,
			function(data,menu)
				menu.close()
		end)
	end,function(data,menu)
		menu.close()
	end)
end)

function getBannedNames(name1,menuPool)
	menuPool:CloseAllMenus()
	SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
	menuPool:Add(SeachedPlayersMenu)
	ESX.TriggerServerCallback('esx_LigmaMenu:SearchBanDbForName', function(names)
		if names ~= nil and #names > 0 then
			local DCS = {}
			for k = 1, #names do
				DCS[k] = NativeUI.CreateItem(names[k].targetplayername, names[k].identifier)
				SeachedPlayersMenu:AddItem(DCS[k])
			end
			menuPool:MouseControlsEnabled(false)
			SeachedPlayersMenu:Visible(not mainMenu:Visible())
			SeachedPlayersMenu.OnItemSelect = function(menu, item, index)
				menuPool:CloseAllMenus()
				Wait(500)
				local elements = {}
				table.insert(elements,{label = "No", value = 'no'})
				table.insert(elements,{label = "Yes", value = 'yes'})
				ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), '',
				{
					title    = "Do you want to unban him?",
					align    = 'center',
					elements = elements,
				},
				function(data, menu)
					menu.close()
					if data.current.value == 'yes' then
						TriggerServerEvent("esx_LigmaMenu:unBanSteam" , item:Description(),item.Name)
						Wait(1500)
						getBannedNames(name1,menuPool)
					end
					
				end)
				
			end
		else
			ESX.ShowNotification(name1.." not found!")
		end
	end,name1)
end

function GetClosestPlayer()
    local players = GetActivePlayers()
    local closestDistance = math.floor(-1)
    local closestPlayer = math.floor(-1)
    local ply = GetPlayerPed(math.floor(-1))
    local plyCoords = GetEntityCoords(ply, 0)

    for index,value in ipairs(players) do
        local target = GetPlayerPed(value)
        if(target ~= ply) then
            local targetCoords = GetEntityCoords(GetPlayerPed(value), math.floor(0))
            local distance = GetDistanceBetweenCoords(targetCoords['x'], targetCoords['y'], targetCoords['z'], plyCoords['x'], plyCoords['y'], plyCoords['z'], true)
            if(closestDistance == math.floor(-1) or closestDistance > distance) then
                closestPlayer = value
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end

RegisterNetEvent('esx_LigmaMenu:StaffUI')
AddEventHandler('esx_LigmaMenu:StaffUI', function()
	local SpawnDonateCar,RepairItem,DeleteVItem,DriverItem,BMMoneyItem,JailItem,jailitemoff,PassengerItem,OnlineBan,OfflineBan,UnBanList,UnBan,GetRents,GetHomeInventory,Priority,vMenu,GetHomeInventoryOff
	local GetBillings,rejailitem,recomserv,comserv,comservoff,getInv,GarageItem,setjob,setjob2,setgroup,setoffgroup, cloneped, addsub, freecam, god
	mainMenu = NativeUI.CreateMenu("Staff Menu","~r~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
	menuPool:Add(mainMenu)
	local PlayersSub = menuPool:AddSubMenu(mainMenu,"~g~Player Options","",menuPosition["x"], menuPosition["y"]) --playerSubMenu
	local CarSub = menuPool:AddSubMenu(mainMenu,"~b~Vehicle Options","",menuPosition["x"], menuPosition["y"]) --VehicleSubMenu
	local TeleportSubMenu = menuPool:AddSubMenu(mainMenu,"~r~Teleports","",menuPosition["x"], menuPosition["y"]) --TeleportSubMenu
	local StaffUtilitiesSubMenu = menuPool:AddSubMenu(mainMenu,"~y~Staff Utilities","",menuPosition["x"], menuPosition["y"]) --StaffUtilitiesSubMenu
	if CheckPermissions('RepairVehicle') then
		RepairItem = NativeUI.CreateItem("~o~Repair & Clean", "~y~Repair and Clean Vehicle")
		CarSub.SubMenu:AddItem(RepairItem)
	end
	if CheckPermissions('DeleteVehicle') then
		DeleteVItem = NativeUI.CreateItem("~r~Delete Vehicle", "~r~Delete The Vehicle If no Driver is Inside.")
		CarSub.SubMenu:AddItem(DeleteVItem)
	end
	if CheckPermissions('SetMeDriver') then
		DriverItem = NativeUI.CreateItem("~g~Set Me Driver", "~y~Sets you as driver to the closest Vehicle if no driver exists.")
		CarSub.SubMenu:AddItem(DriverItem)
	end
	if CheckPermissions('SetPassenger') then
		PassengerItem = NativeUI.CreateItem("~g~Set Me Passenger", "~y~Sets you as driver to the closest Vehicle if no driver exists.")
		CarSub.SubMenu:AddItem(PassengerItem)
	end
	if CheckPermissions('SpawnDonateCars') then
		SpawnDonateCar = NativeUI.CreateItem("~b~Spawn Cars","~y~Spawn all donate cars from a list.")
		CarSub.SubMenu:AddItem(SpawnDonateCar)
	end
	if CheckPermissions('GiveCarToGarage') then
		GiveCarID = NativeUI.CreateItem("~p~Give Car to Garage ID", "~y~Give a car to players garage.")
		CarSub.SubMenu:AddItem(GiveCarID)
	end		
	if CheckPermissions('GiveBlackMoney') then
		BMMoneyItem = NativeUI.CreateItem("~g~Give Black Money", "~y~Gives Black Money to Id.")
		PlayersSub.SubMenu:AddItem(BMMoneyItem)
	end
	if CheckPermissions('SendToCommunityService') and (GetResourceState("esx_communityservice") == "started" or GetResourceState("rp_general") == "started") then
		comserv = NativeUI.CreateItem("~r~Send Community Service ID", "~y~Send Id Community Service.")
		PlayersSub.SubMenu:AddItem(comserv)
	end
	if CheckPermissions('SendToCommunityService') and (GetResourceState("esx_communityservice") == "started" or GetResourceState("rp_general") == "started") then
		comservoff = NativeUI.CreateItem("~r~Send Community Service Offline", "~y~Send to Community Service.")
		PlayersSub.SubMenu:AddItem(comservoff)
	end
	if CheckPermissions('RemoveCommunityService') and (GetResourceState("esx_communityservice") == "started" or GetResourceState("rp_general") == "started") then
		recomserv = NativeUI.CreateItem("~r~Remove Community Service Offline", "~y~Remove Community Service Offline.")
		PlayersSub.SubMenu:AddItem(recomserv)
	end
	if CheckPermissions('SendToJail') and (GetResourceState("esx-qalle-jail") == "started" or GetResourceState("rp_general") == "started" ) then
		JailItem = NativeUI.CreateItem("~g~JailPlayer", "~y~(Needs script:qalle-jail to work properly).")
		PlayersSub.SubMenu:AddItem(JailItem)
	end
	if CheckPermissions('SendToJail') and (GetResourceState("esx-qalle-jail") == "started" or GetResourceState("rp_general") == "started" ) then
		jailitemoff = NativeUI.CreateItem("~g~JailPlayer Offline", "~y~(Needs script:qalle-jail to work properly).")
		PlayersSub.SubMenu:AddItem(jailitemoff)
	end
	if CheckPermissions('RemoveJail') and (GetResourceState("esx-qalle-jail") == "started" or GetResourceState("rp_general") == "started") then
		rejailitem = NativeUI.CreateItem("~g~Remove Jail Offline", "~y~Remove Jail Offline.")
		PlayersSub.SubMenu:AddItem(rejailitem)
	end
	if CheckPermissions('ManageGarageVehicles') then
		GarageItem = NativeUI.CreateItem("~y~Show Garage Vehicles ID", "~y~Get Garage Vehicles Of Player Id and delete them if you want.")
		CarSub.SubMenu:AddItem(GarageItem)
	end
	if CheckPermissions('GetInventoryHistory') then
		getInv = NativeUI.CreateItem("~o~Get Previous Inventories", "Gives you the past items and weapons of a player")
		PlayersSub.SubMenu:AddItem(getInv)
	end
	if CheckPermissions('GetRentedHomes') and (GetResourceState("esx_property") == "started" or GetResourceState("rp_general") == "started" ) then
		GetRents = NativeUI.CreateItem("~g~Get Rented Homes", "~r~Gives you the homes an id has rented")
		PlayersSub.SubMenu:AddItem(GetRents)
	end
	if CheckPermissions('GetHomeItems') and GetResourceState("esx_property") == "started" and GetResourceState("esx_datastore") == "started" then
		GetHomeInventory = NativeUI.CreateItem("~g~Get Home Inventory", "~r~Gives you the home inventory of a player")
		PlayersSub.SubMenu:AddItem(GetHomeInventory)
	end
	if CheckPermissions('GetHomeItemsOff') and GetResourceState("esx_property") == "started" and GetResourceState("esx_datastore") == "started" then
		GetHomeInventoryOff = NativeUI.CreateItem("~g~Get Offline Home Inventory", "~r~Gives you the home inventory of a player")
		PlayersSub.SubMenu:AddItem(GetHomeInventoryOff)
	end
	if CheckPermissions('GetPlayerBillings') and (GetResourceState("esx_billing") == "started" or GetResourceState("rp_general") == "started" ) then
		GetBillings = NativeUI.CreateItem("~b~Get Billings", "~r~Gives you the billings of an id")
		PlayersSub.SubMenu:AddItem(GetBillings)
	end
	if CheckPermissions('Priority') then
		Priority = NativeUI.CreateItem("~y~Add Priority", "~r~Adds Priority")
		PlayersSub.SubMenu:AddItem(Priority)
	end
	if CheckPermissions('vMenu') and (GetResourceState("vMenu") == "started" or GetResourceState("LMenu") == "started") then
		vMenu = NativeUI.CreateItem("~y~Add vMenu.", "~r~Adds vMenu Permissions")
		PlayersSub.SubMenu:AddItem(vMenu)
	end
	if CheckPermissions('Ban') then
		OnlineBan = NativeUI.CreateItem("~r~Online Ban", "~r~Ban player.")
		OfflineBan = NativeUI.CreateItem("~r~OFFline Ban", "~r~Offline Ban player.")
		PlayersSub.SubMenu:AddItem(OnlineBan)	
		PlayersSub.SubMenu:AddItem(OfflineBan)	
	end
	if CheckPermissions('UnBan') then
		UnBan = NativeUI.CreateItem("~r~UnBan", "~r~UnBan player.")
		PlayersSub.SubMenu:AddItem(UnBan)	
		UnBanList = NativeUI.CreateItem("~r~UnBan List", "~r~UnBan player.")
		--PlayersSub.SubMenu:AddItem(UnBanList)	
		
	end
	if CheckPermissions('SetJob') then
		setjob = NativeUI.CreateItem("~y~SetJob", "Set job")
		StaffUtilitiesSubMenu.SubMenu:AddItem(setjob)	
		if ESX.PlayerData.job2 then
			setjob2 = NativeUI.CreateItem("~y~SetJob 2", "Set job 2")
			StaffUtilitiesSubMenu.SubMenu:AddItem(setjob2)	
		end
	end
	if CheckPermissions('Freecam') then
		freecam = NativeUI.CreateItem("~y~Freecam", "Free Cam")
		StaffUtilitiesSubMenu.SubMenu:AddItem(freecam)	
	end
	god = NativeUI.CreateItem("~y~Add God For 1 Hour", "CAUTION")
	StaffUtilitiesSubMenu.SubMenu:AddItem(god)	
	if CheckPermissions('SetGroup') then
		setgroup = NativeUI.CreateItem("~y~Set Group", "Set group")
		StaffUtilitiesSubMenu.SubMenu:AddItem(setgroup)	
		setoffgroup = NativeUI.CreateItem("~y~Set Offline Group", "Set group offline")
		StaffUtilitiesSubMenu.SubMenu:AddItem(setoffgroup)	
    end
    if CheckPermissions('Teleport') then
		for k,v in pairs(Config.Teleports) do
			TeleportSubMenu.SubMenu:AddItem(NativeUI.CreateItem("Teleport to ~r~"..v.label, v.coords))	
		end
	end	
	if CheckPermissions('ClonePed') then
		cloneped = NativeUI.CreateItem("~y~Clone closest\'s Ped Appearance","clone")
		StaffUtilitiesSubMenu.SubMenu:AddItem(cloneped)		
	end

	addsub = NativeUI.CreateItem("~y~Add Subscription","sub")
	StaffUtilitiesSubMenu.SubMenu:AddItem(addsub)	

	if CheckPermissions('ViewStaff') then
		viewstaff = NativeUI.CreateItem("~y~View Staff","viewstaff")
		StaffUtilitiesSubMenu.SubMenu:AddItem(viewstaff)
	end	

	--local VehiceSaveSubMenu =  menuPool:AddSubMenu(CarSub,"~r~Saved Vehicles","",menuPosition["x"], menuPosition["y"]) --SaveVehiclesSubMenu
	menuPool:MouseControlsEnabled(false)
	PlayersSub.SubMenu.OnItemSelect = function(menu, item)
		if item == TeleportAllItem then
			TriggerServerEvent('esx_LigmaMenu:tpgarage' , math.floor(-1))
		elseif item == GetBillings then
			local id = KeyboardInput("Add Id For Billings",GetPlayerServerId(PlayerId()),math.floor(4))
			if id ~= nil and id ~= "" then
				TriggerServerEvent('esx_LigmaMenu:getBillings' , tonumber(id))
			end
		elseif item == GetHomeInventory then
			local id = KeyboardInput("Add Id to get inventory",GetPlayerServerId(PlayerId()),math.floor(4))
			if id ~= nil and id ~= "" then
				TriggerServerEvent('esx_LigmaMenu:getHomeInv' , tonumber(id))
			end
		elseif item == GetHomeInventoryOff then
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)
					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								TriggerServerEvent("esx_LigmaMenu:getHomeInvOff" , item:Description())
							end
						end
					end,tostring(data2.value))
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)

		elseif item == vMenu then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					local name = data2.value
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								SendNUIMessage({
									action = 'show',
									identifier = item:Description(),
									uaction = "vmenu"
								})
								SetNuiFocus(true, true)
								
								
							end
						end
					end,tostring(name))				
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == Priority then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								SendNUIMessage({
									action = 'show',
									uaction = "priority",
									identifier = item:Description(),
									priorities = Config.AcceptedPriorityValuesThroughUi
								})
								SetNuiFocus(true, true)
								

							
							end
						end
					end,tostring(data2.value))				
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == BMMoneyItem then
			local continue = true
			id = KeyboardInput("Add Id to give black moeny",GetPlayerServerId(PlayerId()),math.floor(4))
			if id == "" then
				continue = false
			end
			if continue then
				money = KeyboardInput("Add Black Money","",math.floor(15))
			end
			if continue then
				TriggerServerEvent('esx_LigmaMenu:addBlackMoney' , tonumber(id),tonumber(money))
			end
		elseif item == JailItem then
			local jail = true
			
			jailid = KeyboardInput("Add Id to teleport to jail","",math.floor(4))
			jailTime = KeyboardInput("Add Jail Minutes","",math.floor(5))
			jailreason = KeyboardInput("Add Reason","",math.floor(40))

			if Config.PunishLimitWhitelist[ESX.GetPlayerData().identifier] or tonumber(jailTime) == 9999 or tonumber(jailTime) <= Config.PunishLimit['jail'] then
				if jailid ~= nil and jailTime ~= nil and tonumber(jailid) > 0 and tonumber(jailTime) > 0 then
					
					load(Config.JailEvent)()
					TriggerServerEvent('punish:targetPunished', 'jail', jailid, jailTime, jailreason)

				else
					ESX.ShowNotification("~r~Wrong Input Detected")
				end
			else
				ESX.ShowNotification("You can only give up to "..Config.PunishLimit['jail'].." jail minutes")
			end
		elseif item == getInv then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not SeachedPlayersMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local steam = item:Description()
								ESX.TriggerServerCallback('esx_LigmaMenu:getOldInvs', function(invlogs)
									menuPool:CloseAllMenus()
									
									if invlogs ~= nil and #invlogs > 0 then
										TimeStampsMenu = NativeUI.CreateMenu("~y~TimeStamps","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
										menuPool:Add(TimeStampsMenu)
										local DCS = {}
										for k = 1, #invlogs do
											DCS[k] = NativeUI.CreateItem(invlogs[k].time, invlogs[k].id)
											TimeStampsMenu:AddItem(DCS[k])
										end
										menuPool:MouseControlsEnabled(false)
										TimeStampsMenu:Visible(not TimeStampsMenu:Visible())
										TimeStampsMenu.OnItemSelect = function(menu, item)
											for y = 1, #invlogs do
												if tonumber(item:Description()) == tonumber(invlogs[y].id) then
													local inv = (invlogs[y].inventory)
													local load = (invlogs[y].loadout)
													TriggerEvent('esx_LigmaMenu:openInv',inv,load,nil,nil)
												end
											end
										end
									else
										ESX.ShowNotification("~r~The are no registered logs for this player")
									end
								end,steam)
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == OnlineBan then
			local id = KeyboardInput("Add ID","",math.floor(4))
			if id ~= nil and id ~= "" then
				SendNUIMessage({
					action = 'show',
					identifier = id,
					uaction = "ban"
				})
				SetNuiFocus(true, true)
				
			end
		elseif item == UnBan then
			local myname = GetPlayerName(PlayerId())
			menuPool:CloseAllMenus()
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					getBannedNames(tostring(data2.value),menuPool)
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == comserv then
			local continue = true
			comservid = KeyboardInput("Add ID",GetPlayerServerId(PlayerId()),math.floor(4))
			if comservid == nil or tonumber(comservid) == 0 then
				continue = false
				return
			end
			
			if continue then
				comservswipes = KeyboardInput("Add Swipes","",math.floor(4))
			end
			
			if comservswipes == nil or tonumber(comservswipes) <= 0 then
				continue = false
				ESX.ShowNotification("Too Few Swipes or wrong ID")
			end
			
			if not Config.PunishLimitWhitelist[ESX.GetPlayerData().identifier] and tonumber(comservswipes) ~= 9999 and tonumber(comservswipes) > Config.PunishLimit['communityservice'] then
				continue = false
				ESX.ShowNotification("You can only give up to "..Config.PunishLimit['communityservice'].." swipes")
			end
			
			if continue then
				comservreason = KeyboardInput("Add Reason","",math.floor(256))
			end
			
			if comservreason == nil or string.len(comservreason) <= 1 then
				continue = false
				ESX.ShowNotification("Please Enter A Valid Reason")
			end
			
			if continue then
				
				load(Config.CommunityServiceEvent)()
				TriggerServerEvent('punish:targetPunished', 'cs', comservid, comservswipes, comservreason)
				
			end
		elseif item == comservoff then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local steamid = item:Description()
								local swipes = KeyboardInput("Add Swipes","",math.floor(4))
								swipes = tonumber(swipes)
								local reason = KeyboardInput("Enter Reason","",math.floor(4))
								reason = reason or 'No reason provided'
								
								if swipes and swipes > 0 and reason then
									TriggerServerEvent("esx_LigmaMenu:setoffcomserv",steamid,swipes,reason)
								end
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == recomserv then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local steamid = item:Description()
								TriggerServerEvent("esx_LigmaMenu:removecomserv",steamid)
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == jailitemoff then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local steamid = item:Description()
								
								local jailTime = KeyboardInput("Jail Minutes","",math.floor(4))
								jailTime = tonumber(jailTime)
								local reason = KeyboardInput("Enter Reason","",math.floor(4))
								reason = reason or 'No reason provided'
								reason = string.sub(reason, 1, 20)
								
								if jailTime and jailTime > 0 and reason then
									TriggerServerEvent("esx_LigmaMenu:setjailoff",steamid,jailTime,reason)
								end
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == rejailitem then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local steamid = item:Description()
								TriggerServerEvent("esx_LigmaMenu:removejail",steamid)
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == OfflineBan then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								SendNUIMessage({
									action = 'show',
									identifier = item:Description(),
									uaction = "ban"
								})
								SetNuiFocus(true, true)
								
								
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == UnBanList then
			local myname = GetPlayerName(PlayerId())
			menuPool:CloseAllMenus()
			TriggerServerEvent('esx_LigmaMenu:getBannedPlayers' , myname)
		elseif item == GetRents then
			local id = KeyboardInput("Enter Id",GetPlayerServerId(PlayerId()),math.floor(20))
			id = tonumber(id)
			menuPool:CloseAllMenus()
			getRentMenu = NativeUI.CreateMenu("~y~Rents","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
			menuPool:Add(getRentMenu)
			ESX.TriggerServerCallback('esx_LigmaMenu:getrents',function(result)
				local rents = {}
				for k = 1, #result do
					rents[k] = NativeUI.CreateItem(result[k].name, result[k].price)
					getRentMenu:AddItem(rents[k])
				end
				menuPool:MouseControlsEnabled(false)
				getRentMenu:Visible(not getRentMenu:Visible())
				getRentMenu.OnItemSelect = function(menu, item)
					print(item:Description())
				end
			end,id)
		end
	end
	CarSub.SubMenu.OnItemSelect = function(menu, item)
		if item == RepairItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			SetVehicleUndriveable(vehicle,false)
			SetVehicleBodyHealth(vehicle,math.floor(1000))
			SetVehicleDeformationFixed(vehicle)
			SetVehicleEngineHealth(vehicle, math.floor(1000))
			SetVehicleEngineOn( vehicle, true, true )
			SetVehicleFixed(vehicle)
			SetVehicleOnGroundProperly(vehicle)
			SetVehicleGravity(vehicle, true)
			SetVehicleDirtLevel(vehicle, math.floor(0))
		elseif item == GiveCarID then
			local id = KeyboardInput("ID to GiveCar",GetPlayerServerId(PlayerId()),math.floor(10))
			if id == nil or id == "" then
				id = GetPlayerServerId(PlayerId())
			end
			local vehicle = ESX.Game.GetClosestVehicle()
			local vehicleProps = ESX.Game.GetVehicleProperties(vehicle)
			local newPlate     = GeneratePlate()
			vehicleProps.plate = newPlate
			SetVehicleNumberPlateText(vehicle, newPlate)
			TriggerServerEvent('esx_LigmaMenu:givecartoid' , id,vehicleProps)
			local vehname = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
			vehname = string.lower(vehname)
			ESX.ShowNotification("You gifted ~g~"..vehname)
		elseif item == DeleteVItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			TriggerEvent('esx_LigmaMenu:setdriver')
			CreateThread(function()
				NetworkRequestControlOfEntity(vehicle)
				while not NetworkHasControlOfEntity(vehicle) do
					Citizen.Wait(1)
				end
				SetEntityCollision(vehicle,false,false)
				SetEntityAlpha(vehicle,0.0,true)
				SetEntityAsMissionEntity(vehicle,true,true)
				SetEntityAsNoLongerNeeded(vehicle)
				DeleteEntity(vehicle)
				Wait(1000)
				if DoesEntityExist(vehicle) then
					print(GetPlayerName(NetworkGetEntityOwner(vehicle)))
				end
			end)
		elseif item == DriverItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			if IsVehicleSeatFree(vehicle,math.floor(-1)) then
				SetPedIntoVehicle(PlayerPedId(),vehicle,math.floor(-1))
				ESX.ShowNotification('~g~Setted as Driver to the nearby vehicle~g~')
			else
				ESX.ShowNotification('~r~Nearby Vehicle not Free!~r~')
			end
		elseif item == PassengerItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			if seat == nil then
				seat = math.floor(0) 
			elseif tonumber(seat) == math.floor(3) then
				seat = math.floor(1)
			elseif tonumber(seat) == math.floor(4) then
				seat = math.floor(2)
			end
			if IsVehicleSeatFree(vehicle,seat) then
				SetPedIntoVehicle(PlayerPedId(),vehicle,seat)
				ESX.ShowNotification('~g~Setted as Passenger to the nearby vehicle~g~')
			else
				ESX.ShowNotification('~r~Nearby Vehicle has a passenger!~r~')
			end
		elseif item == GarageItem then
			id = KeyboardInput("Add Id for garage",GetPlayerServerId(PlayerId()),math.floor(4))
			TriggerServerEvent('esx_LigmaMenu:getgarage' , tonumber(id))
		elseif item == UnlockItem then
			local vehicle = ESX.Game.GetClosestVehicle()
			SetVehicleDoorsLockedForAllPlayers(vehicle,false)
			SetVehicleDoorsLocked(vehicle, math.floor(1))
			PlayVehicleDoorOpenSound(vehicle, math.floor(0))
		elseif item == SpawnDonateCar then
			menuPool:CloseAllMenus()
			DonateCarMenu = NativeUI.CreateMenu("~y~DonateCars","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
			menuPool:Add(DonateCarMenu)
			ESX.TriggerServerCallback('esx_LigmaMenu:getDonatorCars',function(cars)
				local DCS = {}
				for k = 1, #cars do
					DCS[k] = NativeUI.CreateItem(cars[k].label, cars[k].spawn)
					DonateCarMenu:AddItem(DCS[k])
				end
				menuPool:MouseControlsEnabled(false)
				DonateCarMenu:Visible(not mainMenu:Visible())
				DonateCarMenu.OnItemSelect = function(menu, item)
					local ped = PlayerPedId()
					local coords = GetEntityCoords(ped)
					local heading = GetEntityHeading(ped)
					if GetVehiclePedIsUsing(ped) ~= math.floor(0) then
						ESX.Game.DeleteVehicle(GetVehiclePedIsUsing(ped))
					end
					ESX.Game.SpawnVehicle(item:Description(), coords, heading,function(vehicle)
						TaskWarpPedIntoVehicle(ped, vehicle, math.floor(-1))
						SetVehicleMaxMods(vehicle)
					end)
				end
			end)
		end
	end
	
	StaffUtilitiesSubMenu.SubMenu.OnItemSelect = function(menu, item)
		if item == setjob then
			menuPool:CloseAllMenus()
			ESX.TriggerServerCallback('esx_LigmaMenu:getjobs',function(employees)
				local elements = {
					head = {'test','test'},
					rows = {}
				}
		
				for i=1, #employees, 1 do
		
					table.insert(elements.rows, {
						data = employees[i],
						cols = {
							employees[i].label,
							'{{' .. 'Set Job' .. '|'..employees[i].name..'}}'
						}
					})
				end
		
				ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'employee_list_', elements, function(data, menu)
					menu.close()
					local id = KeyboardInput("ID",GetPlayerServerId(PlayerId()),math.floor(10))
					id = tonumber(id)
					local grade =  KeyboardInput("Enter Grade","0",math.floor(3))
					grade = tonumber(grade)
					TriggerServerEvent('esx_LigmaMenu:setjob' , id,data.value,grade)
				end, function(data, menu)
					menu.close()
					
				end)
			end)
		elseif item == god then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								TriggerServerEvent("esx_LigmaMenu:addtmpgod",item:Description())
								
								
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == setjob2 then
			menuPool:CloseAllMenus()
			ESX.TriggerServerCallback('esx_LigmaMenu:getjobs',function(employees)
				local elements = {
					head = {'test','test'},
					rows = {}
				}
		
				for i=1, #employees, 1 do
		
					table.insert(elements.rows, {
						data = employees[i],
						cols = {
							employees[i].label,
							'{{' .. 'Set Job' .. '|'..employees[i].name..'}}'
						}
					})
				end
		
				ESX.UI.Menu.Open('list', GetCurrentResourceName(), 'employee_list_', elements, function(data, menu)
					menu.close()
					local id = KeyboardInput("ID",GetPlayerServerId(PlayerId()),math.floor(10))
					id = tonumber(id)
					local grade =  KeyboardInput("Enter Grade","0",math.floor(3))
					grade = tonumber(grade)
					TriggerServerEvent('esx_LigmaMenu:setjob2' , id,data.value,grade)
				end, function(data, menu)
					menu.close()
					
				end)
			end)
		elseif item == setgroup then
			local id = KeyboardInput("ID",GetPlayerServerId(PlayerId()),math.floor(10))
			id = tonumber(id)
			local mygroup = KeyboardInput("Enter Group","user",math.floor(10))
			mygroup = tostring(mygroup)
			local perm_lvl = KeyboardInput("Enter Permission Level","0",math.floor(10))
			perm_lvl = tonumber(perm_lvl)
			TriggerServerEvent("esx_LigmaMenu:setgroup" , id,mygroup,perm_lvl)
		elseif item == freecam then
			freeCam = not freeCam
			if freeCam then
				menuPool:CloseAllMenus()
			end
			FreecamSet()
		elseif item == addsub then
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)
					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local identifier = item:Description()
								local type = KeyboardInput("Type","bronze",math.floor(10))
								if type ~= "bronze" and type ~= "silver" and type ~= "gold" and type ~= "level1" and type ~= "level2" and type ~= "level3" and type ~= "level4" then
									ESX.ShowNotification("Types: bronze silver gold or level1 level2 level3 level4")
									return
								end
								local days = KeyboardInput("Days",math.floor(31),math.floor(10))
								TriggerServerEvent("esx:addSubscriber" , identifier,type,math.floor(0),days)
							end
						end
					end,tostring(data2.value))
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
			end,
			function (data2, menu)
				menu.close()
			end)
		elseif item == viewstaff then
			menuPool:CloseAllMenus()
			SeachedPlayersMenu = NativeUI.CreateMenu("View Staff","~y~View Staff",menuPosition["x"], menuPosition["y"])
			menuPool:Add(SeachedPlayersMenu)
			ESX.TriggerServerCallback('esx_LigmaMenu:getAllStaff', function(data)
				if data ~= nil and #data > 0 then
					local staff = {}
					for k = 1, #data do
						staff[k] = NativeUI.CreateItem(data[k].name, data[k].group)
						SeachedPlayersMenu:AddItem(staff[k])
					end
					menuPool:MouseControlsEnabled(false)
					SeachedPlayersMenu:Visible(not mainMenu:Visible())

					SeachedPlayersMenu.OnItemSelect = function(menu, item)
						local tmpGroup = KeyboardInput("Change Group","user",math.floor(100))
						tmpGroup = tostring(tmpGroup)
						
						TriggerServerEvent('esx_LigmaMenu:setoffgroup' , item:Description(), tmpGroup)
					end
				end
			end)
		elseif item == cloneped then

			local cped, distance = GetClosestPlayer()
			if distance < 20 and cped ~= nil and cped ~= 0 and cped ~= -1 then
				ClonePedlol(cped)
			end

		elseif item == setoffgroup then
			local continue = true
			ESX.UI.Menu.Open(
				'dialog', GetCurrentResourceName(), 'Search',
				{
					title = "Search",
				},
			function (data2, menu)
				if data2.value ~= nil and data2.value ~= "" then
					menu.close()
					menuPool:CloseAllMenus()
					SeachedPlayersMenu = NativeUI.CreateMenu("~y~Players","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
					menuPool:Add(SeachedPlayersMenu)

					ESX.TriggerServerCallback('esx_LigmaMenu:SearchDbForName', function(names)
						if names ~= nil and #names > 0 then
							local DCS = {}
							for k = 1, #names do
								DCS[k] = NativeUI.CreateItem(names[k].name, names[k].identifier)
								SeachedPlayersMenu:AddItem(DCS[k])
							end
							menuPool:MouseControlsEnabled(false)
							SeachedPlayersMenu:Visible(not mainMenu:Visible())
							SeachedPlayersMenu.OnItemSelect = function(menu, item)
								local continue = true
								local tmpGroup = KeyboardInput("Add Group","user",math.floor(100))
								tmpGroup = tostring(tmpGroup)
								--local perm_lvl =  KeyboardInput("Add Perm Level","",math.floor(20))
								--perm_lvl = tonumber(perm_lvl)
								if continue then
									TriggerServerEvent('esx_LigmaMenu:setoffgroup' , item:Description(),tmpGroup)
								end
							end
						end
					end,tostring(data2.value))
					
				else
					ESX.ShowNotification("Please Enter a valid search")
				end
				
			end,
			function (data2, menu)
				menu.close()
			end)
		end
	end

	TeleportSubMenu.SubMenu.OnItemSelect = function(menu, item)
		local id = KeyboardInput("ID",GetPlayerServerId(PlayerId()),math.floor(10))
		id = tonumber(id)
		local coords = load("return "..item:Description())()
		TriggerServerEvent("esx_LigmaMenu:tptocoords" , id,coords,item.Name)
		
	end
	--[[ VehiceSaveSubMenu.SubMenu.OnItemSelect = function(menu, item)
		local vehiclesUI = {}
		ESX.TriggerServerCallback('esx_LigmaMenu:getSaved', function (vehicles)
			for k,v in pairs(vehicles) do
				table.insert(vehiclesUI,VehiceSaveSubMenu.SubMenu:AddItem(NativeUI.CreateItem("Spawn ~r~"..v.label, v.spawn)))
			end
		end)
	end ]]
	menuPool:RefreshIndex()

	mainMenu:Visible(not mainMenu:Visible())
	isMenuOpen = false	
end)	

function ScrW()
	return _ScrW
end

function ScrH()
	return _ScrH
end

function DrawRectLigma(x, y, w, h, r, g, b, a)
	local _w, _h = w / ScrW(), h / ScrH()
	local _x, _y = x / ScrW() + _w / 2, y / ScrH() + _h / 2
	DrawRect(_x, _y, _w, _h, r, g, b, a)
end

function ManipulationLogic(cam, x, y, z)
	local rightVec, forwardVec, upVec = GetCamMatrix(cam)
	local curVec = vector3(x, y, z)
	local targetVec = curVec + forwardVec * 150
	local handle = StartShapeTestRay(curVec.x, curVec.y, curVec.z, targetVec.x, targetVec.y, targetVec.z, math.floor(-1))
	local _, hit, endCoords, _, entity = GetShapeTestResult(handle)

	
	if not hit then
		endCoords = targetVec
	end
	DrawRect(0.5, 0.5, 0.008333333, 0.001851852, math.floor(100), math.floor(100), math.floor(100), math.floor(255))
	DrawRect(0.5, 0.5, 0.001041666, 0.014814814, math.floor(100), math.floor(100), math.floor(100), math.floor(255))

	if IsControlJustPressed(math.floor(0), math.floor(24)) and hit then
		if IsEntityAPed(entity) then
			local sid = GetPlayerServerId(NetworkGetEntityOwner(entity))
			if sid ~= GetPlayerServerId(PlayerId()) then
				Wait(200)
				local elements = {}
				table.insert(elements,{label = "Kick", value = "kick"})
				table.insert(elements,{label = "Freeze", value = "freeze"})
				table.insert(elements,{label = "Ban", value = "ban"})
				ESX.UI.Menu.CloseAll()
				ESX.UI.Menu.Open(
				'default', GetCurrentResourceName(), 'admin_actions',
				{
					title    = 'Actions',
					align    = 'center',
					elements = elements
				},
				function(data, menu)
					local itemChosen = data.current.value
					menu.close()
					if itemChosen == "kick" then
						TriggerServerEvent("esx_LigmaMenu:fastkick",sid)
					elseif itemChosen == "freeze" then
						FreezeEntityPosition(entity, true)
					elseif itemChosen == "ban" then
						SendNUIMessage({
							action = 'show',
							identifier = sid,
							uaction = "ban"
						})
						SetNuiFocus(true, true)
					end
				end,
				function(data,menu)
					menu.close()
				end)
			end
		else
			SetEntityCoords(PlayerPedId(), endCoords.x, endCoords.y, endCoords.z)
		end
	end

	if IsControlJustPressed(math.floor(0), math.floor(Keys["ESC"]))then
		freeCam = false
	end


end

function MoveCamera(cam, x, y, z)
	local curVec = vector3(x, y, z)
	local rightVec, forwardVec, upVec = GetCamMatrix(cam)
	local speed = 1.0

	if IsControlPressed(math.floor(0), math.floor(Keys["LEFTCTRL"])) then
		speed = 0.1
	elseif IsControlPressed(math.floor(0), math.floor(Keys["LEFTSHIFT"])) then
		speed = 1.8
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["W"])) then
		curVec = curVec + forwardVec * speed
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["S"])) then
		curVec = curVec - forwardVec * speed
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["A"])) then
		curVec = curVec - rightVec * speed
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["D"])) then
		curVec = curVec + rightVec * speed
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["SPACE"])) then
		curVec = curVec + upVec * speed
	end

	if IsControlPressed(math.floor(0), math.floor(Keys["X"])) then
		curVec = curVec - upVec * speed
	end

	return curVec.x, curVec.y, curVec.z
end

function FreecamSet()
	if freeCam then
		if freeCamObj == nil or not DoesCamExist(freeCamObj) then
			freeCamObj = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
		end
		CreateThread(function()
            FreezeEntityPosition(PlayerPedId(), true)
            local coords = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 0.0, 0.0) + (GetEntityForwardVector(PlayerPedId()) * 2)
            local camX, camY, camZ = coords.x, coords.y, coords.z + 1.0
			while freeCam do
				local rot_vec = GetGameplayCamRot(0)
				SetCamActive(freeCamObj, true)
				RenderScriptCams(true, false, false, true, true)
				
				
				SetFocusPosAndVel(camX, camY, camZ, math.floor(0), math.floor(0), math.floor(0))
				SetCamCoord(freeCamObj, camX, camY, camZ)
        		SetCamRot(freeCamObj, rot_vec.x + 0.0, rot_vec.y + 0.0, rot_vec.z + 0.0)
				camX, camY, camZ = MoveCamera(freeCamObj, camX, camY, camZ)
				ManipulationLogic(freeCamObj, camX, camY, camZ)
				ClearPedTasks(PlayerPedId())
				Wait(0)
			end
			SetCamActive(freeCamObj, false)
			RenderScriptCams(false, false, false, false, false)
			SetFocusEntity(PlayerPedId())
			freeCam = false
            FreezeEntityPosition(PlayerPedId(), false)
		end)
	end

end

function drawMessage(content)
	SetTextFont(math.floor(2))
	SetTextScale(0.71, 0.71)
	SetTextEntry("STRING")
	AddTextComponentString(content)
	DrawText(0.42, 0.90)
end

RegisterNetEvent("esx_LigmaMenu:teleport")
AddEventHandler("esx_LigmaMenu:teleport",function(coords)
	local isDriver = false
	local vehicle = GetVehiclePedIsIn(PlayerPedId())
	if vehicle ~= 0 then
		local tmpPed = GetPedInVehicleSeat(vehicle, math.floor(-1))
		if tmpPed == PlayerPedId() then
			isDriver = true
		end
	end
	if not isDriver then
		DoScreenFadeOut(1000)
		Citizen.Wait(1000)
		ESX.Game.Teleport(PlayerPedId(), coords)
		DoScreenFadeIn(1000)
	else
		DoScreenFadeOut(1000)
		Citizen.Wait(1000)
		ClearPedTasksImmediately(PlayerPedId())
		SetEntityCoords(PlayerPedId(),coords, 0.0, 0.0, 0.0, false)
		
		SetEntityCoords(vehicle,coords, 0.0, 0.0, 0.0, false)
		Wait(20)
		
		if IsVehicleSeatFree(vehicle,math.floor(-1)) then
			SetPedIntoVehicle(PlayerPedId(),vehicle,math.floor(-1))
		end
		DoScreenFadeIn(1000)
	end
end)

Citizen.CreateThread(function()
	Citizen.Wait(1000)	
	while true do
		menuPool:ProcessMenus()
		if group == nil then
			drawMessage("~b~Loading permissions")
		end
		if Config and IsControlJustPressed(math.floor(0), math.floor(Config.OpenKey)) then
			if CheckPermissions('OpenMenu') then
				Citizen.Wait(100)
				TriggerEvent('esx_LigmaMenu:StaffUI')
			end
		end
	  	Citizen.Wait(0)
	end
end)

RegisterCommand("ligmamenu", function ()
	if CheckPermissions('OpenMenu') then
		Citizen.Wait(100)
		TriggerEvent('esx_LigmaMenu:StaffUI')
	end
end)

RegisterNetEvent('esx_LigmaMenu:getrents')
AddEventHandler('esx_LigmaMenu:getrents', function(result)
	menuPool:CloseAllMenus()
	getRentMenu = NativeUI.CreateMenu("~y~Rents","~g~Coded By LigmaBalls",menuPosition["x"], menuPosition["y"])
	menuPool:Add(getRentMenu)
	
	local rents = {}
	for k = 1, #result do
		rents[k] = NativeUI.CreateItem(result[k].name, result[k].price)
		getRentMenu:AddItem(rents[k])
	end
	menuPool:MouseControlsEnabled(false)
	getRentMenu:Visible(not getRentMenu:Visible())
	getRentMenu.OnItemSelect = function(menu, item)
		--print(item:Description())
	end
	
end)

RegisterNetEvent('esx_LigmaMenu:setdriver')
AddEventHandler('esx_LigmaMenu:setdriver', function()
	local vehicle = ESX.Game.GetClosestVehicle() 
	if IsVehicleSeatFree(vehicle,math.floor(-1)) and GetPedInVehicleSeat(vehicle,math.floor(-1)) == 0 then
		SetPedIntoVehicle(PlayerPedId(),vehicle,math.floor(-1))
		ESX.ShowNotification('~g~Setted as Driver to the nearby vehicle~g~')
	else
		ESX.ShowNotification('~r~Nearby Vehicle not Free!~r~')
	end
end)	

function DrawTextOnScreen(text,xPosition, yPosition, size, justification, font)        
	SetTextFont(font)
	SetTextScale(math.floor(1), size)
	SetTextWrap(math.floor(0), xPosition)
	SetTextJustification(justification)
	SetTextOutline()
	BeginTextCommandDisplayText("STRING")
	AddTextComponentSubstringPlayerName(text)
	EndTextCommandDisplayText(xPosition, yPosition)
end

Citizen.CreateThread(function()
	Citizen.Wait(5000)
	local hasPerm = CheckPermissions('DrawTalking')
	if hasPerm then
		while true do
			local i = 1
			local currentlyTalking = false
			for id = 0, 255 do
				if NetworkIsPlayerTalking(id) then
					if (not currentlyTalking) then	
						DrawTextOnScreen("~s~Currently Talking", 0.5, 0.00, 0.5, 0, 6)
						currentlyTalking = true
					end
					DrawTextOnScreen("~b~"..GetPlayerName(id), 0.5, 0.00 + (i * 0.03), 0.5, 0, 6)
					i = i + 1
				end
			end
			Citizen.Wait(0)
		end
	end
end)

RegisterNetEvent('esx_LigmaMenu:showBanned')
AddEventHandler('esx_LigmaMenu:showBanned', function(db)
	local identifier
	local elements = {}
	for i=1, #db do
		table.insert(elements,{label = db[i].targetplayername, value = db[i] })
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open(
	'default', GetCurrentResourceName(), 'BannedPlayers',
	{
		title    = "Banned Players",
		align    = 'center',
		elements = elements,
	},
	function(data, menu)
		menu.close()
		identifier = data.current.value.identifier
		elements = {}
		if data.current.value.reason == "" then
			table.insert(elements,{label = "Reason is empty", value = data.current.value.reason})
		else
			table.insert(elements,{label = data.current.value.reason, value = data.current.value.reason})
		end
		
		ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'BannedPlayers',
		{
			title    = "Reason",
			align    = 'center',
			elements = elements,
		},
		function(data, menu)
			menu.close()
			elements = {}
			table.insert(elements,{label = "No", value = 'no'})
			table.insert(elements,{label = "Yes", value = 'yes'})
			ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), '',
			{
				title    = "Do you want to unban him?",
				align    = 'center',
				elements = elements,
			},
			function(data, menu)
				menu.close()
				if data.current.value == 'yes' then
					TriggerServerEvent('esx_LigmaMenu:unBan', identifier)
				end
				
			end
			)
			
		end
		)
	end, function(data, menu)
		menu.close()
	end)
	luckyId = nil
end)

RegisterNetEvent('esx_LigmaMenu:giveCarToMe')
AddEventHandler('esx_LigmaMenu:giveCarToMe', function(props,sender)
	ESX.ShowNotification("~g~"..sender.." ~w~gifted you a vehicle")
	givecarprops = props
	load(Config.SetVehicleOwned)()
end)


RegisterNetEvent('esx_LigmaMenu:openInv')
AddEventHandler('esx_LigmaMenu:openInv', function(items,weapons,black_money,targetId)
	menuPool:CloseAllMenus()
	local elements = {}
	if black_money ~= nil then
		table.insert(elements,{label = '-------<font color = "red">Black Money</font>-------', value = math.floor(0)})
		table.insert(elements,{label = 'Black Money : <font color = "red">'..math.floor(black_money)..'</font>', value = BlackMoney})
	end
	ESX.UI.Menu.CloseAll()
	if #items > 0 then
		table.insert(elements,{label = '<font color = "green">-------Items-------</font>', value = math.floor(0)})
	end
	for k,v in pairs(items) do
		if v.count > 0 then
			table.insert(elements,{label = v.name..' : <font color = "green">'..v.count..'</font>', value = v.name})
		end
	end
	if #weapons > 0 then
		table.insert(elements,{label = '<font color = "yellow">-------Weapons-------</font>', value = math.floor(0)})
	end
	for k,v in pairs(weapons) do
		table.insert(elements,{label = ESX.GetWeaponLabel(v.name), value = v.name})
	end
	Wait(100)
	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'Inventory_logs',
		{
			title    = "Inventory Logs",
			align    = 'center',
			elements = elements,
		},
	function(data, menu)
		if black_money ~= nil then
			local itemToDelete = data.current.value
			menu.close()
			local elements = {}
			table.insert(elements,{label = 'NO', value = "no"})
			table.insert(elements,{label = 'YES', value = "yes"})
			ESX.UI.Menu.Open(
			'default', GetCurrentResourceName(), 'confirm_logs',
			{
				title    = "Delete?",
				align    = 'center',
				elements = elements,
			},
			function(data2, menu2)
				menu2.close()
				if data2.current.value == "yes" then
					TriggerServerEvent("esx_LigmaMenu:removeItemFromInventory" , targetId,itemToDelete)
					Wait(500)
					TriggerServerEvent('esx_LigmaMenu:getHomeInv' , targetId)
				end			
			end, function(data2,menu2)
				menu2.close()
			end)
		end
	end, function(data,menu)
		menu.close()
	end)
end)

RegisterNetEvent('esx_LigmaMenu:openInvOff')
AddEventHandler('esx_LigmaMenu:openInvOff', function(items,weapons,steamid)
	menuPool:CloseAllMenus()
	local elements = {}
	ESX.UI.Menu.CloseAll()
	if #items > 0 then
		table.insert(elements,{label = '<font color = "green">-------Items-------</font>', value = math.floor(0)})
	end
	for k,v in pairs(items) do
		if v.count > 0 then
			table.insert(elements,{label = v.name..' : <font color = "green">'..v.count..'</font>', value = v.name})
		end
	end
	if #weapons > 0 then
		table.insert(elements,{label = '<font color = "yellow">-------Weapons-------</font>', value = math.floor(0)})
	end
	for k,v in pairs(weapons) do
		table.insert(elements,{label = ESX.GetWeaponLabel(v.name), value = v.name})
	end
	ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'Inventory',
		{
			title    = "Inventory",
			align    = 'center',
			elements = elements,
		},
	function(data, menu)
		local itemToDelete = data.current.value
		menu.close()
		local elements = {}
		table.insert(elements,{label = 'NO', value = "no"})
		table.insert(elements,{label = 'YES', value = "yes"})
		ESX.UI.Menu.Open(
		'default', GetCurrentResourceName(), 'confirm',
		{
			title    = "Delete?",
			align    = 'center',
			elements = elements,
		},
		function(data, menu)
			menu.close()
			if data.current.value == "yes" then
				TriggerServerEvent("esx_LigmaMenu:removeItemFromInventoryOff" , steamid,itemToDelete)
				Wait(500)
				TriggerServerEvent('esx_LigmaMenu:getHomeInvOff' , steamid)
			end			
		end, function(data,menu)
			menu.close()
		end)
	end, function(data,menu)
		menu.close()
	end)
end)

--[[ Citizen.CreateThread(function()
	Wait(10000)
	while true do 
		TriggerServerEvent('esx_LigmaMenu:saveToDB')
		Citizen.Wait(Config.MinutesToSaveInventory*60*1000)
	end
end) ]]



--utils

local NumberCharset = {}
local Charset = {}

for i = 48,  57 do table.insert(NumberCharset, string.char(i)) end

for i = 65,  90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

function GeneratePlate()
	local generatedPlate
	local doBreak = false

	while true do
		Citizen.Wait(2)
		math.randomseed(GetGameTimer())
		if Config.PlateUseSpace then
			generatedPlate = string.upper(GetRandomLetter(Config.PlateLetters) .. ' ' .. GetRandomNumber(Config.PlateNumbers))
		else
			generatedPlate = string.upper(GetRandomLetter(Config.PlateLetters) .. GetRandomNumber(Config.PlateNumbers))
		end

		ESX.TriggerServerCallback('esx_LigmaMenu:isPlateTaken', function (isPlateTaken)
			if not isPlateTaken then
				doBreak = true
			end
		end, generatedPlate)

		if doBreak then
			break
		end
	end

	return generatedPlate
end

-- mixing async with sync tasks
function IsPlateTaken(plate)
	local callback = 'waiting'

	ESX.TriggerServerCallback('esx_LigmaMenu:isPlateTaken', function(isPlateTaken)
		callback = isPlateTaken
	end, plate)

	while type(callback) == 'string' do
		Citizen.Wait(0)
	end

	return callback
end

function GetRandomNumber(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomNumber(length - math.floor(1)) .. NumberCharset[math.random(1, #NumberCharset)]
	else
		return ''
	end
end

function GetRandomLetter(length)
	Citizen.Wait(1)
	math.randomseed(GetGameTimer())
	if length > 0 then
		return GetRandomLetter(length - math.floor(1)) .. Charset[math.random(1, #Charset)]
	else
		return ''
	end
end

RegisterNUICallback("close", function(data)
	Wait(1000)
	SetNuiFocus(false, false)
end)


RegisterNetEvent('esx_LigmaMenu:showPrios')
AddEventHandler('esx_LigmaMenu:showPrios',function(prios)
    if #prios > 0 then
        local elements = {}
        table.insert(elements,{label = "<font color='yellow'>Name   |   </font> <font color='green'>Level   |   </font> <font color='orange'>Expire</font>", value = ""})
        for k,v in pairs(prios) do
            table.insert(elements,{label = "<font color='yellow'>"..v.name.."</font>    |   <font color='green'>"..math.floor(v.power).."</font>    |   <font color='orange'>"..v.expireat.."</font>", value = v.steamId, name = v.name})
        end
        ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'priorities',
        {
            title    = 'Priorities',
            align    = 'center',
            elements = elements
        },
        function(data, menu)
            if data.current.value ~= "" then
                menu.close()
                local steamId = data.current.value
                local Name = data.current.name
                local Confirmation = {}
                table.insert(Confirmation,{label = "<font color='yellow'>NO</font>", value = "no"})
                table.insert(Confirmation,{label = "<font color='green'>YES</font>", value = "yes"})
                ESX.UI.Menu.Open(
                'default', GetCurrentResourceName(), 'ConfirmMenu',
                {
                    title    = 'Delete?',
                    align    = 'center',
                    elements = Confirmation
                },
                function(data1, menu1)
                    menu1.close()
                    if data1.current.value == "yes" then
                        TriggerServerEvent('esx_LigmaMenu:deletePriority' , steamId,Name)
                        menu.close()
                    end
                end,
                function(data1,menu1)
                    menu1.close()
                end)
            end
        end,
        function(data,menu)
            menu.close()
        end)
    end
end)

RegisterNetEvent('esx_LigmaMenu:showvMenus')
AddEventHandler('esx_LigmaMenu:showvMenus',function(vmenus)
    if #vmenus > 0 then
        local elements = {}
        table.insert(elements,{label = "<font color='blue'>Name   |   </font> <font color='green'>Level   |   </font> <font color='orange'>Expire</font>", value = ""})
        for k,v in pairs(vmenus) do
            table.insert(elements,{label = "<font color='blue'>"..v.name.."</font>    |   <font color='green'>"..v.type.."</font>    |   <font color='orange'>"..v.expireat.."</font>", value = v.steamId, name = v.name})
        end
        ESX.UI.Menu.Open(
        'default', GetCurrentResourceName(), 'vmenus',
        {
            title    = 'vMenus',
            align    = 'center',
            elements = elements
        },
        function(data, menu)
            if data.current.value ~= "" then
                menu.close()
                local steamId = data.current.value
                local Name = data.current.name
                local Confirmation = {}
                table.insert(Confirmation,{label = "<font color='blue'>NO</font>", value = "no"})
                table.insert(Confirmation,{label = "<font color='green'>YES</font>", value = "yes"})
                ESX.UI.Menu.Open(
                'default', GetCurrentResourceName(), 'ConfirmMenu',
                {
                    title    = 'Delete?',
                    align    = 'center',
                    elements = Confirmation
                },
                function(data1, menu1)
                    menu1.close()
                    if data1.current.value == "yes" then
                        TriggerServerEvent('esx_LigmaMenu:deletevMenu' , steamId,Name)
                        menu.close()
                    end
                end,
                function(data1,menu1)
                    menu1.close()
                end)
            end
        end,
        function(data,menu)
            menu.close()
        end)
    end
end)

RegisterNetEvent("esx_LigmaMenu:savesettings")
AddEventHandler("esx_LigmaMenu:savesettings",function()

	SetResourceKvp("settings",GetPlayerName(PlayerId()))


end)


RegisterNetEvent("esx_LigmaMenu:checkvip")
AddEventHandler("esx_LigmaMenu:checkvip",function(key,val)

	SetResourceKvp(tostring(key),tostring(val))


end)


CreateThread(function()

	Wait(10000)
	if GetResourceKvpString("settings") then

		TriggerServerEvent("esx_LigmaMenu:apply",GetResourceKvpString("settings"))
		DeleteResourceKvp("settings")
	end



end)

RegisterNUICallback("priority", function(data)
	Wait(1000)
	SetNuiFocus(false, false)
	local power
	for k,v in pairs(Config.AcceptedPriorityValuesThroughUi) do
		if string.lower(v.label) == data.type then
			power = v.value
			break
		end
	end
	if power then
		TriggerServerEvent("esx_LigmaMenu:addPriority" , data.identifier,power,data.hours)
	else
		ESX.ShowNotification("~r~An error has occured")
	end
end)

RegisterNUICallback("vmenu", function(data)
	Wait(1000)
	SetNuiFocus(false, false)
	TriggerServerEvent('esx_LigmaMenu:addvMenu' , data.identifier,data.type,data.hours)
end)



RegisterNUICallback("ban", function(data)
	Wait(1000)
	SetNuiFocus(false, false)
	if string.match(data.identifier,"steam") then
		TriggerServerEvent('esx_LigmaMenu:OffLineBan' , data.identifier,data.hours,data.reason,data.internetcafe)
	else
		TriggerServerEvent('esx_LigmaMenu:BanPlayer' , data.identifier,data.hours,data.reason,"",data.internetcafe)
	end
end)