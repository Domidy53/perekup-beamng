local M = {}

local MIN_REFERENCE_VALUE = 4000
local MAX_REFERENCE_VALUE = 50000000

local function hash(value)
  local result = 5381
  value = tostring(value or "")
  for index = 1, #value do
    result = (result * 33 + string.byte(value, index)) % 2147483647
  end
  return result
end

local function roundTo(value, step)
  return math.floor(value / step + 0.5) * step
end

local function clamp(value, minimum, maximum)
  return math.min(maximum, math.max(minimum, value))
end

local function declaredValue(config)
  if type(config) ~= "table" then
    return nil
  end
  local value = tonumber(config.value)
  if not value or value ~= value or value <= 0 or value > MAX_REFERENCE_VALUE then
    return nil
  end
  return clamp(value, MIN_REFERENCE_VALUE, MAX_REFERENCE_VALUE)
end

function M.referenceValue(config)
  local value = declaredValue(config)
  if value then
    return roundTo(value, 250)
  end

  local category = type(config) == "table" and tostring(config.type or ""):lower() or ""
  local estimated = category == "truck" and 28000 or 16000
  local power = type(config) == "table" and tonumber(config.power) or nil
  local weight = type(config) == "table" and tonumber(config.weight) or nil
  local performanceClass = type(config) == "table" and tonumber(config.performanceClass) or nil

  if power and power > 0 and power < 2000 then
    estimated = estimated * (1 + clamp(power, 0, 600) / 900)
  end
  if weight and weight > 0 and weight < 100000 then
    estimated = estimated * clamp(weight / (category == "truck" and 4500 or 1600), 0.8, 1.35)
  end
  if performanceClass and performanceClass > 0 then
    estimated = estimated * clamp(1 + (performanceClass - 3) * 0.07, 0.85, 1.4)
  end
  return roundTo(clamp(estimated, MIN_REFERENCE_VALUE, MAX_REFERENCE_VALUE), 250)
end

function M.hasDeclaredValue(config)
  return declaredValue(config) ~= nil
end

function M.conditionFactor(condition)
  condition = clamp(tonumber(condition) or 0, 0, 100)
  return 0.25 + condition * 0.0068
end

function M.listingPrice(config, day, condition)
  local seed = tostring(type(config) == "table" and config.id or config) .. ":listing:" .. tostring(day or 1)
  local variation = 0.94 + (hash(seed) % 1201) / 10000
  local price = M.referenceValue(config) * M.conditionFactor(condition or 35) * variation
  return math.max(1000, roundTo(price, 50))
end

function M.repairCost(vehicle)
  if type(vehicle) ~= "table" then
    return 0
  end
  local condition = clamp(tonumber(vehicle.condition) or 0, 0, 100)
  local points = 100 - condition
  if points <= 0 then
    return 0
  end
  local reference = clamp(tonumber(vehicle.marketValue) or MIN_REFERENCE_VALUE, MIN_REFERENCE_VALUE, MAX_REFERENCE_VALUE)
  return roundTo(math.max(75, reference * 0.08 * points / 100), 25)
end

function M.repairCondition(condition)
  return 100
end

function M.resalePrice(vehicle)
  if type(vehicle) ~= "table" then
    return 0
  end
  local marketValue = clamp(tonumber(vehicle.marketValue) or MIN_REFERENCE_VALUE, MIN_REFERENCE_VALUE, MAX_REFERENCE_VALUE)
  local variation = 0.97 + (hash(vehicle.id or vehicle.modelKey) % 601) / 10000
  return math.max(1000, roundTo(marketValue * M.conditionFactor(vehicle.condition) * variation, 50))
end

return M
