# qb-expandableVehicleTrunk

Custom server-side vehicle inventory weight

# instalation

- first find "if CurrentVehicle ~= nil then -- Trunk" in qb-inventory/client/main.lua
  \*\* then add code below aftter first line ("local vehicleClass = GetVehicleClass(curVeh)")

```lua
local plate = QBCore.Functions.GetPlate(curVeh)
```

\*\* now find code bewlow and edit it as

```lua
local other = {
maxweight = maxweight,
slots = slots,
}
```

```lua
local other = {
                        maxweight = maxweight,
                        slots = slots,
                        plate = plate
                    }
```

- open "inventory:server:OpenInventory" in qb-inventory/server/main.lua and find code below

```lua
end
if Trunks[id].isOpen then
						local Target = QBCore.Functions.GetPlayer(Trunks[id].isOpen)
						if Target ~= nil then
							TriggerClientEvent('inventory:client:CheckOpenState', Trunks[id].isOpen, name, id, Trunks[id].label)
						else
							Trunks[id].isOpen = false
						end
					end
				end



                ( ADD CODE HERE )



				secondInv.name = "trunk-"..id
				secondInv.label = "Trunk-"..id
```

- replace ( ADD CODE HERE ) with code below

```lua
                Result = exports.oxmysql:scalarSync('SELECT `maxweight` FROM player_vehicles WHERE plate = ?',
                    {other.plate})
                if Result then
                    local maxweight_Server = json.decode(Result)
                    other.maxweight = maxweight_Server
                end
```


# Demo

https://raw.githubusercontent.com/swkeep/qb-expandableVehicleTrunk/main/.github/images/1.jpg