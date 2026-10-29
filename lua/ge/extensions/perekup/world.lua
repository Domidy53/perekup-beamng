local M = {}

local extensionState = type(M.state) == "table" and M.state or {}
extensionState.spawned = type(extensionState.spawned) == "table" and extensionState.spawned or {}
extensionState.restoring = type(extensionState.restoring) == "table" and extensionState.restoring or {}
extensionState.nextCallbackNumber = tonumber(extensionState.nextCallbackNumber) or 0
M.state = extensionState

local spawned = extensionState.spawned
local restoring = extensionState.restoring
local MAX_CONFIG_ITEMS = 12000
local STATE_FOLDER = "settings/perekup_vehicle_states"

local function readMember(object, name)
  local ok, value = pcall(function() return object and object[name] end)
  return ok and value or nil
end

local function getObjectById(id)
  local getter = rawget(_G, "getObjectByID")
  if type(getter) == "function" then
    local ok, object = pcall(getter, id)
    if ok and object then return object end
  end
  local backend = rawget(_G, "be")
  local backendGetter = readMember(backend, "getObjectByID")
  if type(backendGetter) == "function" then
    local ok, object = pcall(backendGetter, backend, id)
    if ok and object then return object end
  end
  local tree = rawget(_G, "scenetree")
  local sceneGetter = readMember(tree, "findObjectById")
  if type(sceneGetter) == "function" then
    local ok, object = pcall(sceneGetter, id)
    if ok and object then return object end
  end
  return nil
end

local function objectId(object)
  local getter = readMember(object, "getID") or readMember(object, "getId")
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter, object)
  value = ok and tonumber(value) or nil
  if not value or value ~= math.floor(value) or value < 0 then return nil end
  return value
end

local function safeId(value)
  return type(value) == "string" and #value > 0 and #value <= 64
    and value:match("^[A-Za-z0-9_%-]+$") ~= nil
end

local function safeStatePath(value)
  return type(value) == "string" and #value <= 160
    and value:match("^settings/perekup_vehicle_states/[A-Za-z0-9_%-]+%.json$") ~= nil
end

local function copyJson(value, depth, seen, budget)
  budget.count = budget.count + 1
  if budget.count > MAX_CONFIG_ITEMS then return nil, false end
  local kind = type(value)
  if kind == "nil" or kind == "boolean" then return value end
  if kind == "string" then
    if #value > 4096 or value:find("%z") then return nil, false end
    return value, true
  end
  if kind == "number" then
    if value ~= value or value == math.huge or value == -math.huge then return nil, false end
    return value, true
  end
  if kind ~= "table" or depth > 32 or seen[value] then return nil, false end
  seen[value] = true
  local result = {}
  for key, child in pairs(value) do
    if type(key) ~= "string" and (type(key) ~= "number" or key ~= math.floor(key)) then
      seen[value] = nil
      return nil, false
    end
    local copied, ok = copyJson(child, depth + 1, seen, budget)
    if not ok then
      seen[value] = nil
      return nil, false
    end
    result[key] = copied
  end
  seen[value] = nil
  return result, true
end

local function validConfigSnapshot(snapshot, expectedModel)
  if type(snapshot) ~= "table" or snapshot.model ~= expectedModel or not safeId(snapshot.model)
    or type(snapshot.parts) ~= "table" or type(snapshot.vars) ~= "table" or type(snapshot.paints) ~= "table" then
    return false
  end
  local allowed = { format = true, model = true, licenseName = true, parts = true, vars = true, paints = true }
  for key in pairs(snapshot) do
    if not allowed[key] then return false end
  end
  if snapshot.licenseName ~= nil and (type(snapshot.licenseName) ~= "string"
    or #snapshot.licenseName > 64 or snapshot.licenseName:find("%z") ~= nil) then return false end
  local _, ok = copyJson(snapshot, 1, {}, { count = 0 })
  return ok
end

local function sameData(left, right, seen)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  seen = seen or {}
  if seen[left] == right then return true end
  seen[left] = right
  for key, value in pairs(left) do
    if not sameData(value, right[key], seen) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

function M.captureVehicleConfig(objectIdValue, expectedModel)
  local id = tonumber(objectIdValue)
  if not id or not safeId(expectedModel) then
    return nil, "Не удалось подтвердить автомобиль для чтения конфигурации."
  end
  local manager = rawget(_G, "core_vehicle_manager")
  if type(manager) ~= "table" or type(manager.getVehicleData) ~= "function" then
    local extensionManager = rawget(_G, "extensions")
    manager = readMember(extensionManager, "core_vehicle_manager")
  end
  local getter = readMember(manager, "getVehicleData")
  if type(getter) ~= "function" then
    return nil, "В этой версии игры недоступно чтение текущей конфигурации автомобиля."
  end
  local ok, data = pcall(getter, id)
  local config = ok and type(data) == "table" and data.config or nil
  if type(config) ~= "table" or type(config.parts) ~= "table" then
    return nil, "Игровой каталог ещё не предоставил полный список установленных деталей."
  end
  if (config.vars ~= nil and type(config.vars) ~= "table")
    or (config.paints ~= nil and type(config.paints) ~= "table") then
    return nil, "Игровой каталог вернул повреждённые переменные или окраску; конфигурация не сохранена."
  end
  local model = config.model or expectedModel
  if model ~= expectedModel then
    return nil, "Конфигурация игрового объекта не совпадает с машиной карьеры."
  end

  local snapshot = {
    model = model,
    parts = config.parts,
    vars = type(config.vars) == "table" and config.vars or {},
    paints = type(config.paints) == "table" and config.paints or {}
  }
  if config.format ~= nil then snapshot.format = config.format end
  if config.licenseName ~= nil then snapshot.licenseName = config.licenseName end
  local copied, copyOk = copyJson(snapshot, 1, {}, { count = 0 })
  if not copyOk or not validConfigSnapshot(copied, expectedModel) then
    return nil, "Текущая конфигурация содержит неподдерживаемые данные и не сохранена."
  end
  return copied
end

local function ensureStateDirectory()
  local fs = rawget(_G, "FS")
  if fs == nil or type(readMember(fs, "directoryCreate")) ~= "function"
    or type(readMember(fs, "fileExists")) ~= "function" then
    return false
  end
  if type(readMember(fs, "directoryExists")) == "function" then
    local existsOk, exists = pcall(function() return fs:directoryExists(STATE_FOLDER) end)
    if existsOk and exists == true then return true end
  end
  local ok, result = pcall(function() return fs:directoryCreate(STATE_FOLDER, true) end)
  return ok and result ~= false
end

function M.makeStatePath(vehicleId, token, suffix)
  if not safeId(vehicleId) or not safeId(token)
    or (suffix ~= "state" and suffix ~= "pre" and suffix ~= "post") then
    return nil, "Некорректный путь физического сохранения."
  end
  if not ensureStateDirectory() then
    return nil, "Не удалось подготовить папку физических сохранений в пользовательской папке BeamNG."
  end
  local fs = rawget(_G, "FS")
  for attempt = 1, 8 do
    extensionState.nextCallbackNumber = extensionState.nextCallbackNumber + 1
    local nonce = tostring(os.time()) .. "_" .. tostring(extensionState.nextCallbackNumber) .. "_" .. tostring(attempt)
    local path = STATE_FOLDER .. "/" .. vehicleId .. "_" .. token .. "_" .. nonce .. "_" .. suffix .. ".json"
    local ok, exists = pcall(function() return fs:fileExists(path) end)
    if ok and exists == false then return path end
  end
  return nil, "Не удалось подобрать новое имя файла физического состояния."
end

function M.validateStateFile(path, expectedModel, configSnapshot)
  if not safeStatePath(path) or not safeId(expectedModel) then return false end
  local fs = rawget(_G, "FS")
  if fs == nil or type(readMember(fs, "fileExists")) ~= "function" or type(jsonReadFile) ~= "function" then
    return false
  end
  local existsOk, exists = pcall(function() return fs:fileExists(path) end)
  if not existsOk or exists ~= true then return false end
  if type(readMember(fs, "fileSize")) == "function" then
    local sizeOk, size = pcall(function() return fs:fileSize(path) end)
    if not sizeOk or type(size) ~= "number" or size <= 0 or size > 16 * 1024 * 1024 then return false end
  end
  local readOk, saved = pcall(jsonReadFile, path)
  if not readOk or type(saved) ~= "table" or saved.format ~= "v2"
    or type(saved.model) ~= "string" or saved.model ~= expectedModel
    or type(saved.vehicleDirectory) ~= "string" or #saved.vehicleDirectory > 160 or type(saved.nodeCount) ~= "number"
    or saved.nodeCount < 1 or saved.nodeCount > 200000 or saved.nodeCount ~= math.floor(saved.nodeCount)
    or type(saved.beamCount) ~= "number" or saved.beamCount < 1 or saved.beamCount > 500000
    or saved.beamCount ~= math.floor(saved.beamCount)
    or type(saved.parts) ~= "table" or type(saved.vars) ~= "table"
    or type(saved.nodes) ~= "table" or type(saved.beams) ~= "table" or type(saved.hydros) ~= "table" then
    return false
  end
  if configSnapshot and (not sameData(saved.parts, configSnapshot.parts) or not sameData(saved.vars, configSnapshot.vars or {})) then
    return false
  end
  local nodes, beams = 0, 0
  for _ in pairs(saved.nodes) do nodes = nodes + 1 end
  for _ in pairs(saved.beams) do beams = beams + 1 end
  return nodes == saved.nodeCount and beams == saved.beamCount
end

function M.getObjectId(careerVehicleId)
  local id = spawned[careerVehicleId]
  if id == nil then return nil end
  if getObjectById(id) then return id end
  spawned[careerVehicleId] = nil
  return nil
end

function M.objectExists(id)
  return tonumber(id) ~= nil and getObjectById(tonumber(id)) ~= nil
end

function M.isInWorld(careerVehicleId)
  return M.getObjectId(careerVehicleId) ~= nil
end

local function queueStateRestore(careerVehicleId, objectIdValue, path, modelKey, configSnapshot)
  local object = getObjectById(objectIdValue)
  local queue = readMember(object, "queueLuaCommand")
  if type(queue) ~= "function" then return false, "Lua VM автомобиля недоступен для восстановления состояния." end
  if not M.validateStateFile(path, modelKey, configSnapshot) then
    return false, "Файл физического состояния повреждён или не соответствует конфигурации; автомобиль оставлен в гараже."
  end
  extensionState.nextCallbackNumber = extensionState.nextCallbackNumber + 1
  local token = "L" .. tostring(extensionState.nextCallbackNumber)
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.restoreState("
    .. string.format("%q", path) .. ", " .. string.format("%q", token) .. ")"
  local ok, result = pcall(queue, object, command)
  if not ok or result == false then return false, "Команда восстановления не была принята Lua VM автомобиля." end
  restoring[careerVehicleId] = {
    token = token,
    objectId = tonumber(objectIdValue),
    path = path,
    modelKey = modelKey,
    configSnapshot = configSnapshot,
    retries = 0,
    lastQueuedAt = os.clock()
  }
  return true, token
end

function M.finishStateRestore(token, objectIdValue, succeeded)
  local id = tonumber(objectIdValue)
  for careerVehicleId, pending in pairs(restoring) do
    if pending.token == token and pending.objectId == id then
      restoring[careerVehicleId] = nil
      if succeeded == true then return true, careerVehicleId end
      M.returnToGarage(careerVehicleId)
      return false, careerVehicleId
    end
  end
  return false
end

function M.isRestoring(careerVehicleId)
  return restoring[careerVehicleId] ~= nil
end

function M.spawn(careerVehicleId, config, configSnapshot, stateFile)
  if not safeId(careerVehicleId) or type(config) ~= "table"
    or type(config.modelKey) ~= "string" or not config.modelKey:match("^[%w_%-]+$")
    or type(config.configKey) ~= "string" or #config.configKey == 0 or #config.configKey > 64 then
    return false, "Не удалось подтвердить идентификатор выбранной конфигурации."
  end
  if M.isInWorld(careerVehicleId) then return false, "Эта машина уже находится в игровом мире." end
  if configSnapshot and not validConfigSnapshot(configSnapshot, config.modelKey) then
    return false, "Сохранённая конфигурация машины повреждена; автомобиль оставлен в гараже."
  end
  if stateFile and not M.validateStateFile(stateFile, config.modelKey, configSnapshot) then
    return false, "Не удалось проверить сохранённое физическое состояние; автомобиль оставлен в гараже."
  end
  if type(core_vehicles) ~= "table" or type(core_vehicles.spawnNewVehicle) ~= "function" then
    return false, "В этой версии BeamNG недоступен API появления автомобиля."
  end

  local options = {
    config = configSnapshot and copyJson(configSnapshot, 1, {}, { count = 0 }) or config.configKey,
    autoEnterVehicle = true,
    keepLoaded = true
  }
  local ok, object = pcall(core_vehicles.spawnNewVehicle, config.modelKey, options)
  if not ok or object == nil or object == false then
    return false, "BeamNG не подтвердил появление выбранного автомобиля."
  end
  local id = objectId(object)
  if not id then
    return false, "Автомобиль появился без подтверждённого игрового идентификатора."
  end
  spawned[careerVehicleId] = id
  if stateFile then
    local queued, tokenOrError = queueStateRestore(careerVehicleId, id, stateFile, config.modelKey, configSnapshot)
    if not queued then
      local returned = M.returnToGarage(careerVehicleId)
      if not returned then
        return false, tokenOrError .. " Игровой объект остался в мире, но связь сохранена."
      end
      return false, tokenOrError
    end
    return true, id, tokenOrError
  end
  return true, id
end

function M.adopt(careerVehicleId, objectIdValue)
  local id = tonumber(objectIdValue)
  if not safeId(careerVehicleId) or not id or not getObjectById(id) then return false end
  spawned[careerVehicleId] = id
  return true
end

local function leaveVehicleIfActive(id)
  local backend = rawget(_G, "be")
  local playerGetter = readMember(backend, "getPlayerVehicleID")
  if type(playerGetter) ~= "function" then
    return false, "BeamNG не предоставил проверку активного автомобиля; безопасное сохранение остановлено."
  end
  local ok, playerId = pcall(playerGetter, backend, 0)
  if not ok then return false, "Не удалось проверить, находится ли игрок в сохраняемом автомобиле." end
  if tonumber(playerId) ~= id then return true end
  local walking = readMember(rawget(_G, "gameplay_walk"), "setWalkingMode")
  if type(walking) ~= "function" then return false, "Сначала выйдите из машины, чтобы зафиксировать её состояние." end
  local walkOk, result = pcall(walking, true, nil, nil, true)
  if not walkOk or result == false then return false, "Не удалось безопасно выйти из автомобиля перед сохранением." end
  return true
end

function M.prepareForStateSave(careerVehicleId)
  local id = M.getObjectId(careerVehicleId)
  if not id then return false, "Игровой объект автомобиля больше не существует." end
  local safe, reason = leaveVehicleIfActive(id)
  if not safe then return false, reason end
  return true, id
end

function M.deleteObjectById(objectIdValue)
  local id = tonumber(objectIdValue)
  if not id then return false, "Некорректный идентификатор игрового объекта." end
  local object = getObjectById(id)
  if not object then
    for careerVehicleId, spawnedId in pairs(spawned) do
      if spawnedId == id then spawned[careerVehicleId] = nil end
    end
    for careerVehicleId, pending in pairs(restoring) do
      if pending.objectId == id then restoring[careerVehicleId] = nil end
    end
    return true
  end
  local delete = readMember(object, "delete")
  if type(delete) ~= "function" then return false, "BeamNG не предоставил операцию удаления игрового объекта." end
  local safe, reason = leaveVehicleIfActive(id)
  if not safe then return false, reason end
  local ok, result = pcall(delete, object)
  if not ok or result == false then return false, "BeamNG не подтвердил возврат автомобиля в гараж." end
  for careerVehicleId, spawnedId in pairs(spawned) do
    if spawnedId == id then spawned[careerVehicleId] = nil end
  end
  for careerVehicleId, pending in pairs(restoring) do
    if pending.objectId == id then restoring[careerVehicleId] = nil end
  end
  return true
end

function M.returnToGarage(careerVehicleId)
  local id = M.getObjectId(careerVehicleId)
  if not id then return true end
  return M.deleteObjectById(id)
end

local function queueVehicleCommand(objectIdValue, command)
  local object = getObjectById(objectIdValue)
  local queue = readMember(object, "queueLuaCommand")
  if type(queue) ~= "function" then return false end
  local ok, result = pcall(queue, object, command)
  return ok and result ~= false
end

function M.queueStateSave(objectIdValue, path, token, kind)
  local id = tonumber(objectIdValue)
  if not id or not safeStatePath(path) or not safeId(token)
    or (kind ~= "store" and kind ~= "repair_checkpoint") then
    return false, "Некорректный запрос физического сохранения."
  end
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.saveState("
    .. string.format("%q", path) .. ", " .. string.format("%q", token) .. ", " .. string.format("%q", kind) .. ")"
  if not queueVehicleCommand(id, command) then
    return false, "Команда сохранения не была принята Lua VM автомобиля."
  end
  return true
end

function M.queueRepair(objectIdValue, token, postStateFile)
  local id = tonumber(objectIdValue)
  if not id or not safeId(token) or not safeStatePath(postStateFile) then
    return false, "Некорректный идентификатор ремонта."
  end
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.requestRepair("
    .. string.format("%q", token) .. ", " .. string.format("%q", postStateFile) .. ")"
  if not queueVehicleCommand(id, command) then
    return false, "Команда ремонта не была принята автомобильным Lua VM."
  end
  return true
end

function M.onUpdate()
  local now = os.clock()
  for careerVehicleId, pending in pairs(restoring) do
    if now - (pending.lastQueuedAt or 0) > 20 and pending.retries < 10 then
      if M.objectExists(pending.objectId) then
        local object = getObjectById(pending.objectId)
        local queue = readMember(object, "queueLuaCommand")
        if type(queue) == "function" then
          local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.restoreState("
            .. string.format("%q", pending.path) .. ", " .. string.format("%q", pending.token) .. ")"
          local ok, result = pcall(queue, object, command)
          if ok and result ~= false then
            pending.lastQueuedAt = now
            pending.retries = pending.retries + 1
          end
        end
      else
        restoring[careerVehicleId] = nil
        spawned[careerVehicleId] = nil
      end
    end
  end
end

function M.onVehicleDestroyed(id)
  id = tonumber(id)
  if not id then return end
  for careerVehicleId, spawnedId in pairs(spawned) do
    if spawnedId == id then spawned[careerVehicleId] = nil end
  end
  for careerVehicleId, pending in pairs(restoring) do
    if pending.objectId == id then restoring[careerVehicleId] = nil end
  end
end

return M
