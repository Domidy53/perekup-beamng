local M = {}
local Diagnostics = require("perekup/diagnostics")

-- These bindings are memory-only. The career ID is permanent; the object ID,
-- unique scene-tree name, and callback proof exist only for this runtime session.
local bindings = {}
local restoring = {}
local runtimeCounter = 0
local runtimeGeneration = 0
local runtimeIdentity = "0_" .. tostring(os.time())
  .. "_" .. tostring(math.floor(os.clock() * 1000000))
local MAX_CONFIG_ITEMS = 12000
local STATE_FOLDER = "settings/perekup_vehicle_states"

function M.beginRuntime(generation)
  runtimeGeneration = tonumber(generation) or 0
  runtimeCounter = 0
  bindings = {}
  restoring = {}
  runtimeIdentity = tostring(runtimeGeneration) .. "_" .. tostring(os.time())
    .. "_" .. tostring(math.floor(os.clock() * 1000000))
  return runtimeGeneration
end

local function readMember(object, name)
  local ok, value = pcall(function() return object and object[name] end)
  return ok and value or nil
end

local function objectId(object)
  local getter = readMember(object, "getID") or readMember(object, "getId")
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter, object)
  value = ok and tonumber(value) or nil
  if not value or value ~= math.floor(value) or value < 0 then return nil end
  return value
end

local function objectName(object, expectedId)
  local getter = readMember(object, "getName")
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter, object)
  if ok and type(value) == "string" and #value > 0 then return value end
  ok, value = pcall(getter, object, expectedId)
  return ok and type(value) == "string" and #value > 0 and value or nil
end

local function findNamedObject(name)
  local tree = rawget(_G, "scenetree")
  local finder = readMember(tree, "findObject")
  if type(finder) ~= "function" then return nil, false end
  local ok, object = pcall(finder, name)
  if not ok then return nil, false end
  return object, true
end

local function verifiedNamedObject(id, name)
  local object, lookupAvailable = findNamedObject(name)
  if not lookupAvailable then return nil, false, false end
  if not object then return nil, true, true end
  local currentId = objectId(object)
  local currentName = objectName(object, id)
  if currentId == nil or currentName == nil then return nil, true, false end
  if currentId ~= id or currentName ~= name then return nil, true, true end
  return object, true, false
end

local function nextRuntimeToken(prefix)
  runtimeCounter = runtimeCounter + 1
  return prefix .. runtimeIdentity .. "_" .. tostring(runtimeCounter)
end

local function boundObject(careerVehicleId)
  local binding = bindings[careerVehicleId]
  if type(binding) ~= "table" then return nil end
  local current, lookupAvailable, identityMismatch = verifiedNamedObject(binding.objectId, binding.objectName)
  if current then return binding, current end
  if lookupAvailable and identityMismatch then
    bindings[careerVehicleId] = nil
    restoring[careerVehicleId] = nil
  end
  return nil
end

local function assignUniqueObjectName(object, id)
  local setter = readMember(object, "setName")
  if type(setter) ~= "function" then return nil end
  for _ = 1, 32 do
    local name = "PEREKUP_" .. nextRuntimeToken("O")
    local occupied, lookupAvailable = findNamedObject(name)
    if not lookupAvailable then return nil end
    if not occupied then
      local ok, result = pcall(setter, object, name)
      if ok and result ~= false then
        local current = verifiedNamedObject(id, name)
        if current then return name end
      end
    end
  end
  return nil
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

function M.captureVehicleConfig(careerVehicleId, expectedModel)
  local binding = boundObject(careerVehicleId)
  local id = binding and binding.objectId or nil
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
    Diagnostics.record("vehicle.config.read", "unavailable")
    return nil, "В этой версии игры недоступно чтение текущей конфигурации автомобиля."
  end
  local ok, data = pcall(getter, id)
  local config = ok and type(data) == "table" and data.config or nil
  if type(config) ~= "table" or type(config.parts) ~= "table" then
    Diagnostics.record("vehicle.config.read", ok and "unverified" or "failed")
    return nil, "Игровой каталог ещё не предоставил полный список установленных деталей."
  end
  if (config.vars ~= nil and type(config.vars) ~= "table")
    or (config.paints ~= nil and type(config.paints) ~= "table") then
    return nil, "Игровой каталог вернул повреждённые переменные или окраску; конфигурация не сохранена."
  end
  local model = config.model or expectedModel
  if model ~= expectedModel then
    Diagnostics.record("vehicle.config.read", "unverified")
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
    Diagnostics.record("vehicle.config.read", "failed")
    return nil, "Текущая конфигурация содержит неподдерживаемые данные и не сохранена."
  end
  Diagnostics.record("vehicle.config.read", "ok")
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
    Diagnostics.record("vehicle.state.path", "unavailable")
    return nil, "Не удалось подготовить папку физических сохранений в пользовательской папке BeamNG."
  end
  local fs = rawget(_G, "FS")
  for attempt = 1, 8 do
    local nonce = runtimeIdentity .. "_" .. tostring(os.time()) .. "_" .. tostring(runtimeCounter + attempt)
    local path = STATE_FOLDER .. "/" .. vehicleId .. "_" .. token .. "_" .. nonce .. "_" .. suffix .. ".json"
    local ok, exists = pcall(function() return fs:fileExists(path) end)
    if ok and exists == false then return path end
  end
  Diagnostics.record("vehicle.state.path", "failed")
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
  local binding = boundObject(careerVehicleId)
  return binding and binding.objectId or nil
end

function M.getBindingToken(careerVehicleId)
  local binding = boundObject(careerVehicleId)
  return binding and binding.proof or nil
end

function M.isBound(careerVehicleId, objectIdValue, proof)
  local binding = boundObject(careerVehicleId)
  return binding ~= nil and binding.objectId == tonumber(objectIdValue)
    and type(proof) == "string" and binding.proof == proof
end

function M.isCurrentOperation(careerVehicleId, objectIdValue, proof, operationToken, operationKind)
  local binding = boundObject(careerVehicleId)
  local operation = binding and binding.operation or nil
  return binding ~= nil and binding.objectId == tonumber(objectIdValue)
    and binding.proof == proof and type(operation) == "table"
    and operation.token == operationToken and operation.kind == operationKind
end

function M.isInWorld(careerVehicleId)
  return M.getObjectId(careerVehicleId) ~= nil
end

local function queueBoundCommand(careerVehicleId, command, operationToken, operationKind)
  local binding, object = boundObject(careerVehicleId)
  if not binding then return false, nil, "У этой карьерной машины нет подтверждённого объекта текущей сессии." end
  local queue = readMember(object, "queueLuaCommand")
  if type(queue) ~= "function" then
    Diagnostics.record("vehicle.command.queue", "unavailable")
    return false, nil, "Lua VM автомобиля недоступен."
  end
  local previousOperation = binding.operation
  binding.operation = { token = operationToken, kind = operationKind }
  local ok, result = pcall(queue, object, command)
  if not ok or result == false then
    if binding.operation.token == operationToken and binding.operation.kind == operationKind then
      binding.operation = previousOperation
    end
    Diagnostics.record("vehicle.command.queue", "failed")
    return false, nil, "Команда не была принята Lua VM автомобиля."
  end
  Diagnostics.record("vehicle.command.queue", "ok")
  return true, binding.proof
end

local function queueStateRestore(careerVehicleId, path, modelKey, configSnapshot)
  if not M.validateStateFile(path, modelKey, configSnapshot) then
    return false, "Файл физического состояния повреждён или не соответствует конфигурации; автомобиль оставлен в гараже."
  end
  local token = nextRuntimeToken("L")
  local binding = bindings[careerVehicleId]
  if not binding then return false, "Объект для восстановления больше не подтверждён." end
  restoring[careerVehicleId] = {
    token = token,
    objectId = binding.objectId,
    proof = binding.proof,
    path = path,
    retries = 0,
    lastQueuedAt = os.clock()
  }
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.restoreState("
    .. string.format("%q", path) .. ", " .. string.format("%q", token) .. ", "
    .. string.format("%q", binding.proof) .. ")"
  local queued, _, queueError = queueBoundCommand(careerVehicleId, command, token, "restore")
  if not queued then
    restoring[careerVehicleId] = nil
    return false, queueError
  end
  return true, token
end

function M.finishStateRestore(token, objectIdValue, proof, succeeded)
  local id = tonumber(objectIdValue)
  for careerVehicleId, pending in pairs(restoring) do
    if pending.token == token and pending.objectId == id and pending.proof == proof
      and M.isCurrentOperation(careerVehicleId, id, proof, token, "restore") then
      restoring[careerVehicleId] = nil
      local binding = bindings[careerVehicleId]
      binding.operation = nil
      if succeeded == true then return true, careerVehicleId end
      local removed = M.returnToGarage(careerVehicleId, proof)
      return false, careerVehicleId, removed == true
    end
  end
  Diagnostics.record("vehicle.restore.callback", "unverified")
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
    Diagnostics.record("vehicle.spawn", "unavailable")
    return false, "В этой версии игры недоступен API появления автомобиля."
  end

  local options = {
    config = configSnapshot and copyJson(configSnapshot, 1, {}, { count = 0 }) or config.configKey,
    autoEnterVehicle = true,
    keepLoaded = true
  }
  local ok, object = pcall(core_vehicles.spawnNewVehicle, config.modelKey, options)
  if not ok or object == nil or object == false then
    Diagnostics.record("vehicle.spawn", "failed")
    return false, "BeamNG не подтвердил появление выбранного автомобиля."
  end
  local id = objectId(object)
  if not id then
    Diagnostics.record("vehicle.spawn", "unverified")
    return false, "Автомобиль появился без подтверждённого игрового идентификатора."
  end
  local proof = nextRuntimeToken("B")
  local name = assignUniqueObjectName(object, id)
  if not name then
    Diagnostics.record("vehicle.identity", "unavailable")
    return false, "Автомобиль появился, но безопасный поиск объекта по уникальному имени недоступен. PEREKUP не будет управлять им; при необходимости удалите его вручную."
  end
  bindings[careerVehicleId] = { objectId = id, objectName = name, proof = proof }
  if not boundObject(careerVehicleId) then
    bindings[careerVehicleId] = nil
    Diagnostics.record("vehicle.identity", "failed")
    return false, "Игровой объект появился, но его текущую идентичность нельзя подтвердить. PEREKUP не будет управлять им; при необходимости удалите его вручную."
  end
  Diagnostics.record("vehicle.spawn", "ok")
  if stateFile then
    local queued, tokenOrError = queueStateRestore(careerVehicleId, stateFile, config.modelKey, configSnapshot)
    if not queued then
      M.returnToGarage(careerVehicleId, proof)
      return false, tokenOrError
    end
    return true, id, tokenOrError, proof
  end
  return true, id, nil, proof
end

local function leaveVehicleIfActive(id)
  local backend = rawget(_G, "be")
  local playerGetter = readMember(backend, "getPlayerVehicleID")
  if type(playerGetter) ~= "function" then
    Diagnostics.record("vehicle.exit", "unavailable")
    return false, "BeamNG не предоставил проверку активного автомобиля; безопасное сохранение остановлено."
  end
  local ok, playerId = pcall(playerGetter, backend, 0)
  if not ok then
    Diagnostics.record("vehicle.exit", "failed")
    return false, "Не удалось проверить, находится ли игрок в сохраняемом автомобиле."
  end
  if tonumber(playerId) ~= id then return true end
  local walking = readMember(rawget(_G, "gameplay_walk"), "setWalkingMode")
  if type(walking) ~= "function" then
    Diagnostics.record("vehicle.exit", "unavailable")
    return false, "Сначала выйдите из машины, чтобы зафиксировать её состояние."
  end
  local walkOk, result = pcall(walking, true, nil, nil, true)
  if not walkOk or result == false then
    Diagnostics.record("vehicle.exit", "failed")
    return false, "Не удалось безопасно выйти из автомобиля перед сохранением."
  end
  return true
end

function M.prepareForStateSave(careerVehicleId)
  local binding = boundObject(careerVehicleId)
  if not binding then return false, "Игровой объект этой карьерной машины не подтверждён в текущей сессии." end
  local safe, reason = leaveVehicleIfActive(binding.objectId)
  if not safe then return false, reason end
  return true
end

function M.returnToGarage(careerVehicleId, expectedProof)
  local binding, object = boundObject(careerVehicleId)
  if not binding then return true end
  if expectedProof ~= nil and binding.proof ~= expectedProof then
    return false, "Связь с объектом изменилась; объект оставлен без изменений."
  end
  local delete = readMember(object, "delete")
  if type(delete) ~= "function" then
    Diagnostics.record("vehicle.store.delete", "unavailable")
    return false, "BeamNG не предоставил операцию удаления игрового объекта."
  end
  local safe, reason = leaveVehicleIfActive(binding.objectId)
  if not safe then return false, reason end
  local currentBinding, current = boundObject(careerVehicleId)
  if not currentBinding or currentBinding.proof ~= binding.proof
    or currentBinding.objectId ~= binding.objectId or currentBinding.objectName ~= binding.objectName then
    bindings[careerVehicleId] = nil
    restoring[careerVehicleId] = nil
    Diagnostics.record("vehicle.store.delete", "unverified")
    return false, "Игровой объект изменился после проверки; удаление остановлено."
  end
  binding.deleting = true
  local ok, result = pcall(delete, current)
  if not ok or result == false then
    binding.deleting = false
    Diagnostics.record("vehicle.store.delete", "failed")
    return false, "BeamNG не подтвердил возврат автомобиля в гараж."
  end
  bindings[careerVehicleId] = nil
  restoring[careerVehicleId] = nil
  Diagnostics.record("vehicle.store.delete", "ok")
  return true
end

function M.queueStateSave(careerVehicleId, path, token, kind)
  if not safeId(careerVehicleId) or not safeStatePath(path) or not safeId(token)
    or (kind ~= "store" and kind ~= "repair_checkpoint") then
    return false, "Некорректный запрос физического сохранения."
  end
  local binding = bindings[careerVehicleId]
  if not binding then return false, "Сохранение остановлено: объект не подтверждён PEREKUP в этой сессии." end
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.saveState("
    .. string.format("%q", path) .. ", " .. string.format("%q", token) .. ", "
    .. string.format("%q", kind) .. ", " .. string.format("%q", binding.proof) .. ")"
  local queued, _, queueError = queueBoundCommand(careerVehicleId, command, token, kind)
  if not queued then return false, queueError end
  return true, binding.proof
end

function M.queueRepair(careerVehicleId, token, postStateFile)
  if not safeId(careerVehicleId) or not safeId(token) or not safeStatePath(postStateFile) then
    return false, "Некорректный идентификатор ремонта."
  end
  local binding = bindings[careerVehicleId]
  if not binding then return false, "Ремонт остановлен: объект не подтверждён PEREKUP в этой сессии." end
  local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.requestRepair("
    .. string.format("%q", token) .. ", " .. string.format("%q", postStateFile) .. ", "
    .. string.format("%q", binding.proof) .. ")"
  local queued, _, queueError = queueBoundCommand(careerVehicleId, command, token, "repair")
  if not queued then return false, queueError end
  return true, binding.proof
end

function M.onUpdate()
  local now = os.clock()
  for careerVehicleId, pending in pairs(restoring) do
    local binding, object = boundObject(careerVehicleId)
    if not binding or binding.objectId ~= pending.objectId or binding.proof ~= pending.proof then
      restoring[careerVehicleId] = nil
    elseif now - (pending.lastQueuedAt or 0) > 20 and pending.retries < 10 then
      local queue = readMember(object, "queueLuaCommand")
      if type(queue) == "function" then
        local command = "extensions.load('perekup_vehicle_state'); extensions.perekup_vehicle_state.restoreState("
          .. string.format("%q", pending.path) .. ", " .. string.format("%q", pending.token) .. ", "
          .. string.format("%q", pending.proof) .. ")"
        local ok, result = pcall(queue, object, command)
        if ok and result ~= false then
          pending.lastQueuedAt = now
          pending.retries = pending.retries + 1
        end
      end
    end
  end
end

function M.onVehicleDestroyed(id)
  id = tonumber(id)
  if not id then return {} end
  local affected = {}
  for careerVehicleId, binding in pairs(bindings) do
    if binding.objectId == id then
      local current, lookupAvailable, identityMismatch = verifiedNamedObject(id, binding.objectName)
      -- A destruction hook carries only a numeric ID. Keep the binding if the
      -- runtime-only name and ID still resolve, regardless of Lua wrapper identity.
      if not binding.deleting and lookupAvailable and identityMismatch then
        affected[#affected + 1] = {
          careerVehicleId = careerVehicleId,
          proof = binding.proof,
          operation = binding.operation
        }
        bindings[careerVehicleId] = nil
        restoring[careerVehicleId] = nil
        Diagnostics.record("vehicle.object", "missing")
      end
    end
  end
  return affected
end

return M
