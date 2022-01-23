ESX = nil
Citizen.CreateThread(function()
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(10)
    end
end)
--[[------------------------------------------
Prison Core Code
]]--------------------------------------------
RegisterNetEvent('bixbi_prison:SendToPrison')
AddEventHandler('bixbi_prison:SendToPrison', function(data)
    local playerPed = PlayerPedId()
    if (IsPedInAnyVehicle(playerPed, true)) then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        DeleteEntity(vehicle)
    end

    DoScreenFadeOut(2000)

    if (Config.OxInventory) then TriggerEvent('ox_inventory:disarm') end
    
    local sex = 0
    if (exports['fivem-appearance']:getPedModel(playerPed) == 'mp_f_freemode_01') then sex = 1 end

    for k, v in pairs(Config.Uniform) do
        local drawable = v.male.drawable
        local texture = v.male.texture
        if (sex == 1) then
            drawable = v.female.drawable
            texture = v.female.texture
        end

        TriggerEvent('bixbi_core:SetClothing', k, drawable, texture)
    end

    Citizen.Wait(2000)
    SetEntityCoords(playerPed, Config.PrisonLocation, false, false, false, false)
    TriggerEvent('esx_policejob:unrestrain')
    Citizen.Wait(1500)
    DoScreenFadeIn(2000)

    exports['bixbi_core']:Notify('error', 'You have been imprisoned for ' .. data.time .. ' month(s)', 10000)
    exports['bixbi_core']:Notify('', 'Prison Reason: ' .. data.reason .. ' | Arresting Officer: ' .. data.officer, 10000)
end)

RegisterNetEvent('bixbi_prison:ReleaseFromPrison')
AddEventHandler('bixbi_prison:ReleaseFromPrison', function()
    DoScreenFadeOut(2000)
    Citizen.Wait(2000)

    ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin)
        -- TriggerEvent('skinchanger:loadSkin', skin)
        exports['fivem-appearance']:setPlayerAppearance(skin)
    end)

    SetEntityCoords(PlayerPedId(), Config.ReleaseLocation, false, false, false, false)
    Citizen.Wait(1500)
    DoScreenFadeIn(2000)
end)

RegisterNetEvent('bixbi_prison:DistanceCheck')
AddEventHandler('bixbi_prison:DistanceCheck', function(distance)
    if (distance > 250) then
        local playerPed = PlayerPedId()

        DoScreenFadeOut(2000)
        if (IsPedInAnyVehicle(playerPed, true)) then
            local vehicle = GetVehiclePedIsIn(playerPed, false)
            DeleteEntity(vehicle)
        end
        Citizen.Wait(2000)
        
        SetEntityCoords(playerPed, Config.PrisonLocation, false, false, false, false)
        Citizen.Wait(1500)
        DoScreenFadeIn(2000)
        exports['bixbi_core']:Notify('error', 'It looks like something went wrong. You have been returned to prison by the guards.')
    end
end)

--[[------------------------------------------
Prison Management
]]--------------------------------------------
local prisoners = {}
local releaseCount = 0
local terminalAccess = false
function Setup()
    exports['qtarget']:AddBoxZone('Bixbi_Prison_Terminal', Config.TerminalLocation, 1.0, 1.0, {
        name='Prison Terminal',
        heading=0,
        -- debugPoly=false,
        minZ=44.0,
        maxZ=48.0
    }, {
        options = {
            {
                event = "bixbi_prison:GainTerminalAccess",
                icon = "fas fa-lock",
                label = "Gain Terminal Access",
                item = Config.PrisonBreakItem,
            },
            {
                event = "bixbi_prison:TerminalMenu",
                icon = "fas fa-terminal",
                label = "Open Terminal",
            },
        },
        distance = 3.0
    })

    exports['qtarget']:AddBoxZone('Bixbi_Prison_Info', Config.PrisonInfo, 1.0, 1.0, {
        name='Prison Information',
        heading=0,
        debugPoly=false,
        minZ=44.0,
        maxZ=48.0
    }, {
        options = {
            {
                event = "bixbi_prison:ImprisonmentInformation",
                icon = "fas fa-terminal",
                label = "Prison Information",
            },
        },
        distance = 3.0
    })

    
    exports['qtarget']:Player({
        options = {
            {
                event = "bixbi_prison:Prison",
                icon = "fas fa-house-user",
                label = "[PD] Prison",
                job = "police",
                canInteract = function(entity)
                    if IsPedAPlayer(entity) then
                        local targetId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
                        return (Player(targetId).state.handcuffed and not IsPedDeadOrDying(entity, 1))
                    end
                end
            },
        },
        distance = 2.0
    })

    local blip = AddBlipForCoord(Config.PrisonLocation)
    SetBlipSprite (blip, 188)
    SetBlipDisplay(blip, 6)
    SetBlipScale  (blip, 1.0)
    SetBlipColour (blip, 3)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.BlipName)
    EndTextCommandSetBlipName(blip)
end

AddEventHandler('bixbi_prison:Prison', function(data)
    local dialog = exports['zf_dialog']:DialogInput({
        header = "Send to Prison", 
        rows = {
            {
                id = 0, 
                txt = "Length (1 = 1 Minute)"
            },
            {
                id = 1, 
                txt = "Reason"
            }
        }
    })
    if dialog ~= nil then
        if dialog[1].input == nil or dialog[2].input == nil then return end
        TriggerServerEvent('bixbi_prison:JailPlayer', GetPlayerServerId(PlayerId()), GetPlayerServerId(NetworkGetPlayerIndexFromPed(data.entity)), dialog[1].input, dialog[2].input)
    end
end)

RegisterNetEvent('bixbi_prison:ImprisonmentInformation')
AddEventHandler('bixbi_prison:ImprisonmentInformation', function(data)
    TriggerServerEvent('bixbi_prison:ServerPrisonerInfo')
end)

RegisterNetEvent('bixbi_prison:GainTerminalAccess')
AddEventHandler('bixbi_prison:GainTerminalAccess', function(data)
    if (ESX.PlayerData.job.name ~= 'police') then
        ESX.TriggerServerCallback('bixbi_core:jobCount', function(result)
            if (result < Config.MinimumPolice) then
                exports['bixbi_core']:Notify('error', 'There\'s not enough police online.')
                return
            end

            if (exports['bixbi_core']:itemCount('usb_prisonbreak') > 0) then
                StartHacking()
            else
                exports['bixbi_core']:Notify('error', 'You do not have a Prison Break USB.', 10000)
            end
        end, 'police')
    else
        TerminalAccessLoop()
    end
end)

function TerminalAccessLoop()
    exports['bixbi_core']:Notify('success', 'Terminal Access Verified', 10000)
    if (ESX.PlayerData.job.name ~= 'police') then
        terminalAccess = true

        ESX.SetTimeout(Config.TerminalAccessMinutes * 60000, function()
            terminalAccess = false
            prisoners = nil
            releaseCount = 0
        end)
    end
end

AddEventHandler('bixbi_prison:TerminalMenu', function(data)
    if (not terminalAccess and ESX.PlayerData.job.name ~= 'police') then 
        exports['bixbi_core']:Notify('error', 'You do not have access to the terminal', 10000)
        return 
    end

    ESX.TriggerServerCallback('bixbi_prison:ReturnPrisoners', function(prisoners)
        while (prisoners == nil) do Citizen.Wait(100) end
        if (#prisoners == 0) then
            exports['bixbi_core']:Notify('error', 'There is no-one in prison at this current time.')
            return
        end
        local elements = {}
        for k, v in pairs(prisoners) do
            if (v.time > 0) then
                table.insert(elements, {id = #elements+1, header = v.prisoner .. ' [' .. v.officer .. ']', txt = 'Time: ' .. v.time .. ' - ' .. v.reason, params = { event = 'bixbi_prison:TerminalMenuRelease', args = { prisonerId = k }}})
            end
        end
        exports['zf_context']:openMenu(elements)
    end)
end)

AddEventHandler('bixbi_prison:TerminalMenuRelease', function(data)
    if (not terminalAccess and ESX.PlayerData.job.name ~= 'police') then 
        exports['bixbi_core']:Notify('error', 'You do not have access to the terminal', 10000)
        return 
    end

    if (ESX.PlayerData.job.name == 'police' or releaseCount < Config.MaxReleaseCount) then
        TriggerServerEvent('bixbi_prison:UnJailPlayer', data.prisonerId, false)
        releaseCount = releaseCount + 1
        TriggerEvent('bixbi_prison:TerminalMenu')
    else
        exports['bixbi_core']:Notify('error', 'You have released too many people', 10000)
        exports['bixbi_core']:Notify('error', 'Terminal access lost', 10000)
        terminalAccess = false
        prisoners = nil
        releaseCount = 0
    end
end)

--[[------------------------------------------
Prison Breakout
]]--------------------------------------------
local captureDuration = 0
local captureBlip = nil
function StartHacking()
    local playerPed = PlayerPedId()
    TriggerServerEvent('bixbi_dispatch:Add', GetPlayerServerId(PlayerId()), 'police', 'prisonbreak', 'There is a prison break in progress!', GetEntityCoords(playerPed))
    TabletAnim()

    -- Credit: https://github.com/ultrahacx/ultra-voltlab 
    TriggerEvent('ultra-voltlab', 60, function(result, reason)
        Citizen.Wait(3000)
        if (result == 1) then
            TriggerServerEvent('bixbi_core:removeItem', nil, Config.PrisonBreakItem, 1)
            CaptureBegin()
        else
            exports.bixbi_core:Notify('error', string.upper(reason))
        end
        TabletAnim(true)
    end)
end

function TabletAnim(endAnim)
    local playerPed = PlayerPedId()
    local animDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
    local tabletProp = "prop_cs_tablet"
    if (endAnim) then
        StopAnimTask(playerPed, animDict, "base" ,8.0, -8.0, -1, 50, 0, false, false, false)
        DetachEntity(tabletObject, true, false)
        DeleteEntity(tabletObject)
    else
        RequestAnimDict(animDict)
        RequestModel(tabletProp)
        while not HasAnimDictLoaded(animDict) or not HasModelLoaded(tabletProp) do Citizen.Wait(100) end
        tabletObject = CreateObject(GetHashKey(tabletProp), 0.0, 0.0, 0.0, true, true, false)
        AttachEntityToEntity(tabletObject, playerPed, GetPedBoneIndex(playerPed, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
        SetModelAsNoLongerNeeded(tabletProp)
        TaskPlayAnim(playerPed, animDict, "base" , 3.0, 3.0, -1, 49, 0, 0, 0, 0)
    end
end

function CaptureBegin()
    captureDuration = Config.HackingTime * 60000
    exports['bixbi_core']:Notify('', 'Hacking the prison terminal, this will take ' .. math.ceil(captureDuration / 60000) .. ' mins', 8000)
    captureBlip = AddBlipForRadius(Config.TerminalLocation, 20.0)
    SetBlipColour(captureBlip, 1)

    local blip = AddBlipForRadius(Config.TerminalLocation, 70.0)
    SetBlipSprite(blip, 9)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, 1)
    SetBlipAlpha(blip, 200)
    SetBlipAsShortRange(blip, true)
    SetBlipFlashes(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Prison Break in Progress')
    EndTextCommandSetBlipName(blip)

    Citizen.CreateThread(function()
        Citizen.Wait(60000)
        RemoveBlip(blip)
    end)

    Citizen.CreateThread(function()
		while (ESX.PlayerLoaded) do
			Citizen.Wait(5000)
            local playerPed = PlayerPedId()
			if (captureDuration > 0) then
				local playerCoords = GetEntityCoords(playerPed)
				local distance = #(playerCoords - Config.TerminalLocation)
				if (distance > 20.0) then
					exports['bixbi_core']:Notify('error', 'Hacking Failed! You went too far from the zone.', 8000)
                    RemoveBlip(captureBlip)
                    captureBlip = nil
                    break
                elseif (captureBlip ~= nil) then
					captureDuration = captureDuration - 5000
                else
                    break
				end
			else
				TerminalAccessLoop()
                RemoveBlip(captureBlip)
                captureBlip = nil
                break
			end
		end
	end)
end

--[[--------------------------------------------------
Setup
--]]--------------------------------------------------
AddEventHandler('onResourceStart', function(resourceName)
	if (resourceName == GetCurrentResourceName()) then
        while (ESX == nil) do Citizen.Wait(100) end        
        Citizen.Wait(10000)
        ESX.PlayerLoaded = true
        Setup()
        if (ESX.PlayerData.job.name == 'police') then terminalAccess = true end
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
    while (ESX == nil) do Citizen.Wait(100) end    
    ESX.PlayerData = xPlayer
 	ESX.PlayerLoaded = true
    Setup()
    if (ESX.PlayerData.job.name == 'police') then terminalAccess = true end
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
	ESX.PlayerLoaded = false
	ESX.PlayerData = {}
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
    if (ESX.PlayerData.job.name == 'police') then
        terminalAccess = true
    else
        terminalAccess = false
    end
end)

AddEventHandler('esx:onPlayerDeath', function(data)
    if (captureBlip ~= nil and captureDuration ~= 0) then
        exports['bixbi_core']:Notify('error', 'Hacking Failed! You went too far from the zone.', 8000)
        RemoveBlip(captureBlip)
        captureBlip = nil
    end
end)
