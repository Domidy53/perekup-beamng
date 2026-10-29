local Economy = require("perekup/economy")

local M = {}
local MAX_LISTINGS = 12

function M.create(configs, day)
  local candidates = {}
  for _, config in ipairs(configs or {}) do
    candidates[#candidates + 1] = {
      config = config,
      price = Economy.listingPrice(config, day, 35),
      marketValue = Economy.referenceValue(config)
    }
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
      status = "available"
    }
  end
  return listings
end

return M
