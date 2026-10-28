local M = {}

local function cleanText(value, fallback, limit)
  if type(value) ~= "string" then
    return fallback
  end
  value = value:gsub("[%c]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$") or ""
  if value == "" then
    return fallback
  end
  return value:sub(1, limit or 64)
end

local function safeKey(value)
  return type(value) == "string" and #value > 0 and #value <= 64 and value:match("^[%w_%-]+$") ~= nil
end

local function isVehicleType(value)
  if type(value) ~= "string" then
    return true
  end
  local kind = value:lower()
  return kind ~= "prop" and kind ~= "trailer" and kind ~= "unknown"
end

local function makeToken(identity, used)
  local first, second = 5381, 131
  for index = 1, #identity do
    local byte = string.byte(identity, index)
    first = (first * 33 + byte) % 2147483647
    second = (second * 31 + byte) % 2147483629
  end
  local base = string.format("C%010d%010d", first, second)
  local token, suffix = base, 1
  while used[token] do
    suffix = suffix + 1
    token = base .. "_" .. tostring(suffix)
  end
  used[token] = true
  return token
end

function M.discover(rawModels, rawConfigs)
  local modelByKey = {}
  for _, raw in pairs(type(rawModels) == "table" and rawModels or {}) do
    if type(raw) == "table" then
      local key = raw.key or raw.Key
      local kind = raw.Type or raw.type
      if safeKey(key) and isVehicleType(kind) and not modelByKey[key] then
        local brand = cleanText(raw.Brand or raw.brand, "Другая марка", 48)
        local name = cleanText(raw.Name or raw.name, key, 64)
        modelByKey[key] = {
          key = key,
          brand = brand,
          modelName = name,
          type = cleanText(kind, "Автомобиль", 24)
        }
      end
    end
  end

  local result, seen = {}, {}
  for _, raw in pairs(type(rawConfigs) == "table" and rawConfigs or {}) do
    if type(raw) == "table" then
      local modelKey = raw.model_key or raw.modelKey
      local configKey = raw.key or raw.Key
      local model = modelByKey[modelKey]
      if model and type(configKey) == "string" and #configKey > 0 and #configKey <= 64
        and configKey:find("%z") == nil then
        local identity = modelKey .. "|" .. configKey
        if not seen[identity] then
          seen[identity] = true
          local configName = cleanText(raw.Configuration or raw.configuration, nil, 48)
          if not configName then
            configName = cleanText(raw.Name or raw.name, configKey, 48)
          end
          result[#result + 1] = {
            modelKey = model.key,
            configKey = configKey,
            configName = configName,
            brand = model.brand,
            modelName = model.modelName,
            displayName = model.brand .. " " .. model.modelName .. " · " .. configName,
            type = model.type,
            identity = identity
          }
        end
      end
    end
  end

  table.sort(result, function(left, right)
    if left.modelKey == right.modelKey then
      return left.configKey < right.configKey
    end
    return left.modelKey < right.modelKey
  end)
  local usedTokens = {}
  for _, config in ipairs(result) do
    config.id = makeToken(config.identity, usedTokens)
    config.identity = nil
  end
  return result
end

function M.findConfig(configs, modelKey, configKey)
  for _, config in ipairs(configs or {}) do
    if config.modelKey == modelKey and config.configKey == configKey then
      return config
    end
  end
  return nil
end

function M.findConfigById(configs, configId)
  for _, config in ipairs(configs or {}) do
    if config.id == configId then
      return config
    end
  end
  return nil
end

function M.starterOptions(configs)
  local result, seenModels = {}, {}
  for _, config in ipairs(configs or {}) do
    if not seenModels[config.modelKey] then
      seenModels[config.modelKey] = true
      result[#result + 1] = config
      if #result >= 3 then
        break
      end
    end
  end
  return result
end

return M
