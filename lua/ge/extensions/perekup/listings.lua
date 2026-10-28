local Economy = require("perekup/economy")

local M = {}
local MAX_LISTINGS = 12

function M.create(configs, day, garageVehicles)
  local owned = {}
  for _, vehicle in ipairs(garageVehicles or {}) do
    if vehicle.status ~= "sold" then
      owned[vehicle.modelKey .. "|" .. vehicle.configKey] = true
    end
  end

  local function collect(includeOwned)
    local listings = {}
    for _, config in ipairs(configs or {}) do
      if includeOwned or not owned[config.modelKey .. "|" .. config.configKey] then
        local index = #listings + 1
        listings[index] = {
          id = string.format("L%d_%03d_%s", day, index, config.id),
          modelKey = config.modelKey,
          configKey = config.configKey,
          configName = config.configName,
          brand = config.brand,
          name = config.modelName,
          displayName = config.displayName,
          type = config.type,
          price = Economy.listingPrice(config.id, day),
          marketValue = Economy.referenceValue(config.id, day),
          status = "available"
        }
        if #listings >= MAX_LISTINGS then
          break
        end
      end
    end
    return listings
  end

  local listings = collect(false)
  if #listings == 0 and #(configs or {}) > 0 then
    -- A small installation may have only cars already in the player's garage.
    -- Keep the market playable by listing a separate used example of that model.
    listings = collect(true)
  end
  return listings
end

return M
