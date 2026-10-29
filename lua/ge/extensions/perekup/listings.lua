local Economy = require("perekup/economy")

local M = {}
local MAX_LISTINGS = 12

function M.create(configs, day, starter)
  local candidates = {}
  for _, config in ipairs(configs or {}) do
    candidates[#candidates + 1] = {
      config = config,
      price = Economy.listingPrice(config, day, 35),
      marketValue = Economy.referenceValue(config),
      condition = 35
    }
  end

  if day == 1 and type(starter) == "table" then
    local budget = 500 + Economy.resalePrice(starter)
    local affordable = false
    for _, candidate in ipairs(candidates) do
      local repairReserve = Economy.repairCost({
        condition = candidate.condition,
        marketValue = candidate.marketValue
      })
      if candidate.price + repairReserve <= budget then
        affordable = true
        break
      end
    end
    if not affordable then
      for _, candidate in ipairs(candidates) do
        if candidate.config.modelKey == starter.modelKey and candidate.config.configKey == starter.configKey then
          candidate.condition = 20
          candidate.price = Economy.listingPrice(candidate.config, day, candidate.condition)
          break
        end
      end
    end
  end

  table.sort(candidates, function(left, right)
    if left.price == right.price then
      return left.config.id < right.config.id
    end
    return left.price < right.price
  end)

  local listings = {}
  for index = 1, math.min(MAX_LISTINGS, #candidates) do
    local candidate = candidates[index]
    local config = candidate.config
    listings[index] = {
      id = string.format("L%d_%03d_%s", day, index, config.id),
      modelKey = config.modelKey,
      configKey = config.configKey,
      configName = config.configName,
      brand = config.brand,
      name = config.modelName,
      displayName = config.displayName,
      type = config.type,
      price = candidate.price,
      marketValue = candidate.marketValue,
      valueSource = Economy.hasDeclaredValue(config) and "metadata" or "estimate",
      power = config.power,
      weight = config.weight,
      performanceClass = config.performanceClass,
      status = "available",
      condition = candidate.condition
    }
  end
  return listings
end

return M
