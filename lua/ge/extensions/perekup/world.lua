local M = {}
local spawned = {}

local function readMember(object, name)
  local ok, value = pcall(function()
    return object and object[name]
  end)
  return ok and value or nil
end

local function getObjectById(objectId)
  local getter = rawget(_G, "getObjectByID")
  if type(getter) == "function" then
    local ok, object = pcall(getter, objectId)
    if ok and object then
      return object
    end
  end
  local backend = rawget(_G, "be")
  local backendGetter = readMember(backend, "getObjectByID")
  if type(backendGetter) == "function" then
    local ok, object = pcall(backendGetter, backend, objectId)
    if ok and object then
      return object
    end
  end
  local sceneTree = rawget(_G, "scenetree")
  local sceneGetter = readMember(sceneTree, "findObjectById")
  if type(sceneGetter) == "function" then
    local ok, object = pcall(sceneGetter, objectId)
    if ok and object then
      return object
    end
  end
  return nil
end

local function objectId(object)
  local getter = readMember(object, "getID") or readMember(object, "getId")
  if type(getter) ~= "function" then
    return nil
  end
  local ok, value = pcall(getter, object)
  value = ok and tonumber(value) or nil
  if not value or value ~= math.floor(value) or value < 0 then
    return nil
  end
  return value
end

local function safeCarId(value)
  return type(value) == "string" and value:match("^[A-Za-z0-9_-]+$") ~= nil and #value <= 64
end

function M.getObjectId(careerVehicleId)
  local id = spawned[careerVehicleId]
  if id == nil then
    return nil
  end
  if getObjectById(id) then
    return id
  end
  spawned[careerVehicleId] = nil
  return nil
end

function M.objectExists(id)
  return tonumber(id) ~= nil and getObjectById(tonumber(id)) ~= nil
end

function M.isInWorld(careerVehicleId)
  return M.getObjectId(careerVehicleId) ~= nil
end

function M.spawn(careerVehicleId, config)
  if not safeCarId(careerVehicleId) or type(config) ~= "table"
    or type(config.modelKey) ~= "string" or not config.modelKey:match("^[%w_%-]+$")
    or type(config.configKey) ~= "string" or #config.configKey == 0 or #config.configKey > 64 then
    return false, "Не удалось подтвердить идентификатор выбранной конфигурации."
  end
  if M.isInWorld(careerVehicleId) then
    return false, "Эта машина уже находится в игровом мире."
  end
  if type(core_vehicles) ~= "table" or type(core_vehicles.spawnNewVehicle) ~= "function" then
    return false, "В этой версии BeamNG недоступен API появления автомобиля."
  end

  local ok, object = pcall(core_vehicles.spawnNewVehicle, config.modelKey, {
    config = config.configKey,
    autoEnterVehicle = true,
    keepLoaded = true
  })
  if not ok or object == nil or object == false then
    return false, "BeamNG не подтвердил появление выбранного автомобиля."
  end
  local id = objectId(object)
  if not id then
    return false, "Автомобиль появился без подтверждённого игрового идентификатора."
  end
  spawned[careerVehicleId] = id
  return true, id
end

function M.returnToGarage(careerVehicleId)
  local id = M.getObjectId(careerVehicleId)
  if not id then
    return true
  end
  local object = getObjectById(id)
  local delete = readMember(object, "delete")
  if type(delete) ~= "function" then
    return false, "BeamNG не предоставил операцию удаления игрового объекта."
  end
  local backend = rawget(_G, "be")
  local playerVehicleGetter = readMember(backend, "getPlayerVehicleID")
  if type(playerVehicleGetter) == "function" then
    local playerOk, playerId = pcall(playerVehicleGetter, backend, 0)
    if playerOk and tonumber(playerId) == id then
      local walk = rawget(_G, "gameplay_walk")
      local setWalkingMode = readMember(walk, "setWalkingMode")
      if type(setWalkingMode) ~= "function" then
        return false, "Сначала выйдите из автомобиля: режим пешком недоступен."
      end
      local walkOk, walkResult = pcall(setWalkingMode, true, nil, nil, true)
      if not walkOk or walkResult == false then
        return false, "Не удалось безопасно выйти из автомобиля."
      end
    end
  end
  local ok, result = pcall(delete, object)
  if not ok or result == false then
    return false, "BeamNG не подтвердил возврат автомобиля в гараж."
  end
  spawned[careerVehicleId] = nil
  return true
end

function M.queueRepair(objectIdValue, token)
  local id = tonumber(objectIdValue)
  if not id or not safeCarId(token) then
    return false, "Некорректный идентификатор ремонта."
  end
  local object = getObjectById(id)
  local queue = readMember(object, "queueLuaCommand")
  if type(queue) ~= "function" then
    return false, "Автомобильный Lua VM недоступен для ремонта."
  end
  local command = "extensions.load('perekup_repair'); extensions.perekup_repair.requestRepair('" .. token .. "')"
  local ok, result = pcall(queue, object, command)
  if not ok or result == false then
    return false, "Команда ремонта не была принята автомобильным Lua VM."
  end
  return true
end

function M.onVehicleDestroyed(id)
  id = tonumber(id)
  if not id then
    return
  end
  for careerVehicleId, spawnedId in pairs(spawned) do
    if spawnedId == id then
      spawned[careerVehicleId] = nil
    end
  end
end

return M
