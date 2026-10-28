local M = {}

local function hash(value)
  local result = 5381
  value = tostring(value or "")
  for index = 1, #value do
    result = (result * 33 + string.byte(value, index)) % 2147483647
  end
  return result
end

local function round(value)
  return math.floor(value + 0.5)
end

function M.referenceValue(modelKey, day)
  return 700 + hash(tostring(modelKey) .. ":" .. tostring(day or 1)) % 1301
end

function M.listingPrice(modelKey, day)
  return 220 + hash(tostring(modelKey) .. ":listing:" .. tostring(day or 1)) % 281
end

function M.repairCost()
  return 75
end

function M.repairCondition(condition)
  return math.min(100, math.max(0, condition) + 35)
end

function M.resalePrice(vehicle)
  local condition = math.min(100, math.max(0, tonumber(vehicle.condition) or 0))
  local marketValue = math.max(0, tonumber(vehicle.marketValue) or 0)
  local repairCost = math.max(0, tonumber(vehicle.repairCost) or 0)
  local conditionFactor = 0.45 + condition * 0.0055
  return round(marketValue * conditionFactor + repairCost * 0.9)
end

return M
