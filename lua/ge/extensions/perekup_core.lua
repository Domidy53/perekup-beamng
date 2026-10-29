local Career = require("perekup/career")
local Economy = require("perekup/economy")
local Garage = require("perekup/garage")
local Storage = require("perekup/persistence")
local Vehicles = require("perekup/vehicles")
local World = require("perekup/world")

local M = {}
local store = Storage.new()
local state
local loadError
local loadWarning
local lastMessage
local loadAttempted = false
local pendingRepairStartedAt
local lastRepairAck
local repairAckRetryAt
local pendingStoreStartedAt
local lastStoreAck
local storeAckRetryAt
local pendingStateRetryAt

local function loadCareer()
  if loadAttempted then
    return
  end
  loadAttempted = true
  state, loadError = store.load()
  if state and loadError then
    loadWarning = loadError
    loadError = nil
  end
end

local function getCatalog()
  if type(core_vehicles) ~= "table" or type(core_vehicles.getModelList) ~= "function"
    or type(core_vehicles.getConfigList) ~= "function" then
    return {}, "Каталог автомобилей BeamNG сейчас недоступен."
  end
  local modelsOk, modelCatalog = pcall(core_vehicles.getModelList, true)
  local configsOk, configCatalog = pcall(core_vehicles.getConfigList, true)
  if not modelsOk or not configsOk or type(modelCatalog) ~= "table" or type(modelCatalog.models) ~= "table"
    or type(configCatalog) ~= "table" or type(configCatalog.configs) ~= "table" then
    return {}, "Не удалось прочитать каталог автомобилей BeamNG."
  end
  return Vehicles.discover(modelCatalog.models, configCatalog.configs), nil
end

local function isStarterOption(configs, configId)
  for _, config in ipairs(Vehicles.starterOptions(configs)) do
    if config.id == configId then
      return config
    end
  end
  return nil
end

local function publicState(configs, catalogError)
  loadCareer()
  local result = {
    status = loadError and "error" or (state and "active" or "new"),
    message = lastMessage,
    warning = loadWarning,
    catalogError = catalogError,
    availableConfigurationCount = #configs,
    starterOptions = Vehicles.starterOptions(configs)
  }
  if state then
    result.career = Career.copy(state)
    for _, vehicle in ipairs(result.career.vehicles) do
      vehicle.inWorld = World.isInWorld(vehicle.id)
      vehicle.worldObjectId = World.getObjectId(vehicle.id)
      vehicle.repairQuote = Economy.repairCost(vehicle)
      vehicle.conditionSource = "estimate"
      vehicle.physicalStateSaved = type(vehicle.beamStateFile) == "string"
      vehicle.stateRestorePending = World.isRestoring(vehicle.id)
      if not catalogError then
        vehicle.modelAvailable = Vehicles.findConfig(configs, vehicle.modelKey, vehicle.configKey) ~= nil
      end
      vehicle.configSnapshot = nil
      vehicle.beamStateFile = nil
    end
    result.career.pendingRepair = nil
    result.career.pendingStore = nil
    result.pendingStore = state.pendingStore and {
      vehicleId = state.pendingStore.vehicleId,
      status = "saving"
    } or nil
    result.pendingRepair = state.pendingRepair and {
      vehicleId = state.pendingRepair.vehicleId,
      phase = state.pendingRepair.phase
    } or nil
  end
  return result
end

local function publish(configs, catalogError)
  if not configs then
    configs, catalogError = getCatalog()
  end
  local snapshot = publicState(configs or {}, catalogError)
  if type(guihooks) == "table" and type(guihooks.trigger) == "function" then
    pcall(guihooks.trigger, "PerekupSnapshot", snapshot)
  end
end

local function failure(message)
  lastMessage = message
  publish()
  return false
end

local function commit(candidate, successMessage)
  if not store.save(candidate, state) then
    return failure("Сохранение не подтверждено. Операция отменена, баланс и гараж не изменены.")
  end
  state = candidate
  loadError = nil
  loadWarning = nil
  lastMessage = successMessage
  publish()
  return true
end

local function cancelPendingRepair(message)
  if not state or type(state.pendingRepair) ~= "table" then
    return false
  end
  if state.schema >= 2 and state.pendingRepair.phase ~= "checkpoint" then
    return failure("Физический reset уже мог начаться. Операция останется ожидающей и не спишет деньги до проверенного результата.")
  end
  local token = state.pendingRepair.token
  local candidate = Career.copy(state)
  local ok = Career.cancelPhysicalRepair(candidate, token)
  if not ok then
    return failure("Не удалось закрыть незавершённый ремонт. Баланс сохранён без изменений.")
  end
  local saved = commit(candidate, message)
  if saved then
    pendingRepairStartedAt = nil
    lastRepairAck = nil
    repairAckRetryAt = nil
  else
    pendingRepairStartedAt = os.clock() - 30
    repairAckRetryAt = os.clock() + 1
  end
  return saved
end

local function mutate(action, successMessage)
  loadCareer()
  if loadError then
    return failure(loadError)
  end
  if not state then
    return failure("Сначала начните новую карьеру.")
  end
  if state.pendingRepair then
    return failure("Дождитесь подтверждения текущего ремонта.")
  end
  if state.pendingStore then
    return failure("Дождитесь завершения сохранения автомобиля в гараж.")
  end
  local candidate = Career.copy(state)
  local ok, message = action(candidate)
  if not ok then
    return failure(message or "Действие не выполнено.")
  end
  return commit(candidate, successMessage)
end

local function resumeRepairOnObject(vehicleId, objectId)
  if not state or not state.pendingRepair or state.pendingRepair.vehicleId ~= vehicleId then return false end
  local token = state.pendingRepair.token
  local candidate = Career.copy(state)
  if candidate.pendingRepair.phase == "checkpoint" then
    local pending = candidate.pendingRepair
    local vehicle = Garage.findById(candidate.vehicles, vehicleId)
    if not World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
      lastMessage = "Исходный физический checkpoint ремонта недоступен. Операция сохранена без списания и требует восстановления совместимой машины."
      publish()
      return false
    end
    local advanced = Career.startPhysicalRepair(candidate, token)
    if not advanced then return false end
  end
  if objectId ~= nil and candidate.pendingRepair.objectId ~= tonumber(objectId) then
    local rebound = Career.attachPhysicalRepairObject(candidate, token, objectId)
    if not rebound then return false end
  end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить связь незавершённого ремонта с новой игровой машиной. Баланс не изменён.")
  end
  state = candidate
  pendingRepairStartedAt = os.clock()
  pendingStateRetryAt = os.clock() + 20
  if objectId == nil or not World.objectExists(objectId) then
    pendingRepairStartedAt = nil
    lastMessage = "Checkpoint сохранён. Выведите эту машину из гаража, чтобы продолжить ожидающий ремонт."
    publish()
    return true
  end
  World.adopt(vehicleId, objectId)
  local queued, err = World.queueRepair(objectId, token, state.pendingRepair.postStateFile)
  if not queued then
    lastMessage = err .. " Операция останется ожидающей и не спишет деньги."
    publish()
    return false
  end
  lastMessage = "Исходное состояние восстановлено; физический ремонт повторно запущен с прежним токеном."
  publish()
  return true
end

function M.requestSnapshot()
  loadCareer()
  local configs, catalogError = getCatalog()
  publish(configs, catalogError)
  return true
end

function M.startCareer(configId)
  loadCareer()
  if loadError then
    return failure(loadError)
  end
  if state then
    return failure("Карьера уже существует. Продолжите её из текущего сохранения.")
  end
  local configs, catalogError = getCatalog()
  if catalogError then
    return failure(catalogError)
  end
  local config = isStarterOption(configs, configId)
  if not config then
    return failure("Выбранная машина не входит в список доступных стартовых автомобилей. Обновите список.")
  end
  local candidate, err = Career.start(config, configs)
  if not candidate then
    return failure(err)
  end
  local starter = candidate.vehicles[1]
  local spawned, spawnError = World.spawn(starter.id, config)
  if not spawned then
    return failure(spawnError)
  end
  local saved = commit(candidate, "Карьера начата. Машина появилась в игровом мире; на балансе $500.")
  if not saved then
    local returned = World.returnToGarage(starter.id)
    if not returned then
      lastMessage = "Сохранение не подтверждено. Начальная машина появилась, но запись карьеры не была сохранена."
      publish()
    end
  end
  return saved
end

function M.buyListing(listingId)
  return mutate(function(candidate)
    return Career.buy(candidate, listingId)
  end, "Автомобиль куплен и добавлен в гараж.")
end

function M.repairVehicle(vehicleId)
  loadCareer()
  if loadError then return failure(loadError) end
  if not state then return failure("Сначала начните новую карьеру.") end
  if state.pendingRepair or state.pendingStore then return failure("Дождитесь завершения текущей операции с автомобилем.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Ремонт доступен только для машины в вашем гараже.")
  end
  local objectId = World.getObjectId(vehicleId)
  if objectId == nil then
    return failure("Сначала выведите эту машину в игровой мир.")
  end

  local configSnapshot, configError = World.captureVehicleConfig(objectId, vehicle.modelKey)
  if not configSnapshot then return failure(configError) end
  local operationNumber = tonumber(state.nextOperationNumber) or 1
  local token = "R" .. tostring(operationNumber)
  local preStateFile, prePathError = World.makeStatePath(vehicle.id, token, "pre")
  if not preStateFile then return failure(prePathError) end
  local postStateFile, postPathError = World.makeStatePath(vehicle.id, token, "post")
  if not postStateFile then return failure(postPathError) end

  local candidate = Career.copy(state)
  local started, tokenOrError = Career.beginPhysicalRepair(
    candidate, vehicleId, objectId, configSnapshot, preStateFile, postStateFile)
  if not started then return failure(tokenOrError) end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить резерв операции. Ремонт не запущен.")
  end
  state = candidate
  pendingRepairStartedAt = os.clock()
  lastRepairAck = nil
  repairAckRetryAt = nil
  pendingStateRetryAt = os.clock() + 20
  local queued, queueError = World.queueStateSave(objectId, preStateFile, tokenOrError, "repair_checkpoint")
  if not queued then
    cancelPendingRepair("Команда ремонта не принята. Деньги не списаны.")
    return failure(queueError)
  end
  lastMessage = "Сохраняется исходное физическое состояние машины перед ремонтом. Списание ещё не выполнено."
  publish()
  return true
end

function M.listVehicle(vehicleId)
  if World.isInWorld(vehicleId) then
    return failure("Сначала верните машину в гараж; находящийся в мире автомобиль нельзя выставить на продажу.")
  end
  return mutate(function(candidate)
    return Career.listForSale(candidate, vehicleId)
  end, "Автомобиль выставлен на продажу.")
end

function M.sellVehicle(vehicleId)
  if World.isInWorld(vehicleId) then
    return failure("Сначала верните машину в гараж; находящийся в мире автомобиль продать нельзя.")
  end
  return mutate(function(candidate)
    return Career.sell(candidate, vehicleId)
  end, "Продажа записана. Баланс обновлён.")
end

function M.retrieveVehicle(vehicleId)
  loadCareer()
  if loadError then return failure(loadError) end
  if not state then return failure("Сначала начните новую карьеру.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Эту машину нельзя вывести в игровой мир.")
  end
  if state.pendingStore then return failure("Дождитесь завершения сохранения автомобиля в гараж.") end
  local pendingRepair = state.pendingRepair
  if pendingRepair and pendingRepair.vehicleId ~= vehicleId then
    return failure("Сначала восстановите машину, на которой ожидает ремонта карьера.")
  end
  local repairResume = pendingRepair ~= nil
  local configSnapshot = repairResume and pendingRepair.configSnapshot or vehicle.configSnapshot
  local stateFile = repairResume and pendingRepair.preStateFile or vehicle.beamStateFile
  local config
  if configSnapshot then
    config = { modelKey = vehicle.modelKey, configKey = vehicle.configKey }
  else
    local configs, catalogError = getCatalog()
    if catalogError then return failure(catalogError) end
    config = Vehicles.findConfig(configs, vehicle.modelKey, vehicle.configKey)
    if not config then return failure("Конфигурация машины недоступна в текущей установке.") end
  end
  if repairResume and (not stateFile or not World.validateStateFile(stateFile, vehicle.modelKey, configSnapshot)) then
    return failure("Исходный физический checkpoint ремонта отсутствует или несовместим. Повторный reset остановлен; деньги не списаны, операция остаётся ожидающей.")
  elseif not repairResume and stateFile and not World.validateStateFile(stateFile, vehicle.modelKey, configSnapshot) then
    return failure("Физическое сохранение не совпадает с текущей конфигурацией. Машина оставлена в гараже.")
  end
  local spawned, spawnResult, restoreToken = World.spawn(vehicleId, config, configSnapshot, stateFile)
  if not spawned then return failure(spawnResult) end
  local spawnedObjectId = tonumber(spawnResult)
  if repairResume and not restoreToken then
    if not resumeRepairOnObject(vehicleId, spawnedObjectId) then return true end
  end
  if repairResume then
    lastMessage = stateFile
      and "Восстанавливается исходное физическое состояние; после подтверждения ремонт будет повторен без второго списания."
      or "Состояние машины не удалось восстановить; повтор ремонта ожидает подтверждения игрового объекта."
  elseif restoreToken then
    lastMessage = "Машина появилась. Восстанавливаются её конфигурация и сохранённое физическое состояние."
  else
    lastMessage = vehicle.configSnapshot
      and "Машина появилась с сохранённой конфигурацией."
      or "Машина появилась в игровом мире с конфигурацией объявления."
  end
  publish()
  return true
end

function M.returnVehicle(vehicleId)
  loadCareer()
  if loadError then return failure(loadError) end
  if not state then return failure("Сначала начните новую карьеру.") end
  if state.pendingRepair or state.pendingStore then return failure("Дождитесь завершения текущей операции с автомобилем.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Эту машину нельзя вернуть в гараж.")
  end

  local prepared, objectIdOrError = World.prepareForStateSave(vehicleId)
  if not prepared then return failure(objectIdOrError) end
  local objectId = objectIdOrError
  local configSnapshot, configError = World.captureVehicleConfig(objectId, vehicle.modelKey)
  if not configSnapshot then return failure(configError) end
  local operationNumber = tonumber(state.nextOperationNumber) or 1
  local token = "S" .. tostring(operationNumber)
  local stateFile, pathError = World.makeStatePath(vehicle.id, token, "state")
  if not stateFile then return failure(pathError) end

  local candidate = Career.copy(state)
  local started, tokenOrError = Career.beginVehicleStore(candidate, vehicleId, objectId, configSnapshot, stateFile)
  if not started then return failure(tokenOrError) end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить резерв операции. Игровой объект оставлен в мире.")
  end
  state = candidate
  pendingStoreStartedAt = os.clock()
  lastStoreAck = nil
  storeAckRetryAt = nil
  pendingStateRetryAt = os.clock() + 20
  local queued, queueError = World.queueStateSave(objectId, stateFile, tokenOrError, "store")
  if not queued then
    local cancel = Career.copy(state)
    Career.cancelVehicleStore(cancel, tokenOrError)
    commit(cancel, "Сохранение физического состояния не началось. Машина осталась в мире.")
    return failure(queueError)
  end
  lastMessage = "Сохраняются текущая конфигурация и физическое состояние. Машина останется в мире до подтверждения записи."
  publish()
  return true
end

function M.advanceDay()
  local configs, catalogError = getCatalog()
  if catalogError then
    return failure(catalogError)
  end
  return mutate(function(candidate)
    return Career.advanceDay(candidate, configs)
  end, "Наступил новый день. Объявления обновлены.")
end

local function clearStoreRuntime()
  pendingStoreStartedAt = nil
  lastStoreAck = nil
  storeAckRetryAt = nil
  pendingStateRetryAt = nil
end

local function clearRepairRuntime()
  pendingRepairStartedAt = nil
  lastRepairAck = nil
  repairAckRetryAt = nil
  pendingStateRetryAt = nil
end

local function finalizeStore(token, callbackObjectId)
  if not state or type(state.pendingStore) ~= "table" or state.pendingStore.token ~= token then return false end
  local pending = state.pendingStore
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if not vehicle or not World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
    return false
  end

  local targetId = tonumber(callbackObjectId)
  if not targetId or not World.objectExists(targetId) then targetId = tonumber(pending.objectId) end
  if targetId and World.objectExists(targetId) then World.adopt(vehicle.id, targetId) end
  local deleted, deleteError = World.returnToGarage(vehicle.id)
  if not deleted then
    lastMessage = deleteError .. " Сохранённый файл проверен; завершение операции будет повторено."
    storeAckRetryAt = os.clock() + 1
    publish()
    return false
  end

  local candidate = Career.copy(state)
  local completed, completeError = Career.completeVehicleStore(candidate, token)
  if not completed then
    lastMessage = completeError
    publish()
    return false
  end
  local saved = commit(candidate, "Конфигурация и физическое состояние автомобиля сохранены; объект возвращён в гараж.")
  if saved then
    clearStoreRuntime()
  else
    lastStoreAck = { token = token, objectId = tonumber(callbackObjectId) or tonumber(pending.objectId) }
    storeAckRetryAt = os.clock() + 1
  end
  return saved
end

local function cancelStore(message)
  if not state or type(state.pendingStore) ~= "table" then return false end
  local token = state.pendingStore.token
  local candidate = Career.copy(state)
  local ok = Career.cancelVehicleStore(candidate, token)
  if not ok then return false end
  local saved = commit(candidate, message)
  if saved then
    clearStoreRuntime()
  else
    storeAckRetryAt = os.clock() + 1
  end
  return saved
end

local function finalizeRepair(token, objectId)
  if not state or type(state.pendingRepair) ~= "table" then return false end
  local pending = state.pendingRepair
  if pending.token ~= token or pending.phase ~= "reset" then return false end
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if not vehicle or not World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
    return false
  end
  local id = tonumber(objectId)
  if id and World.objectExists(id) then World.adopt(vehicle.id, id) end

  local candidate = Career.copy(state)
  local ok, err = Career.completePhysicalRepair(candidate, token)
  if not ok then
    lastMessage = err
    publish()
    return false
  end
  local saved = commit(candidate, "Физический reset и сохранённое состояние подтверждены; списана одна стоимость ремонта.")
  if saved then
    clearRepairRuntime()
  else
    lastRepairAck = { token = token, objectId = id or pending.objectId, succeeded = true }
    repairAckRetryAt = os.clock() + 1
  end
  return saved
end

local function cancelRejectedRepair(token, objectId)
  if not state or type(state.pendingRepair) ~= "table" then return false end
  local pending = state.pendingRepair
  if pending.token ~= token or pending.phase ~= "reset" or pending.objectId ~= tonumber(objectId) then return false end
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
    return finalizeRepair(token, objectId)
  end
  local candidate = Career.copy(state)
  local ok = Career.cancelPhysicalRepair(candidate, token)
  if not ok then return false end
  local saved = commit(candidate, "Игровой объект отклонил reset до его запуска. Деньги не списаны.")
  if saved then clearRepairRuntime() end
  return saved
end

function M.onVehicleStateSaved(token, objectId, kind, succeeded)
  loadCareer()
  local id = tonumber(objectId)
  if not state then return false end

  if kind == "store" and type(state.pendingStore) == "table" and state.pendingStore.token == token then
    local pending = state.pendingStore
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      return finalizeStore(token, id)
    end
    if succeeded == false and id == tonumber(pending.objectId) then
      return cancelStore("Физическое сохранение не прошло проверку. Предыдущая запись автомобиля сохранена, объект остался в мире.")
    end
    pendingStoreStartedAt = os.clock() - 20
    return false
  end

  if kind == "repair_checkpoint" and type(state.pendingRepair) == "table"
    and state.pendingRepair.token == token and state.pendingRepair.phase == "checkpoint" then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
      return resumeRepairOnObject(pending.vehicleId, id)
    end
    if succeeded == false and id == tonumber(pending.objectId) then
      return cancelPendingRepair("Исходный физический checkpoint не прошёл проверку. Ремонт отменён без списания.")
    end
    pendingStateRetryAt = os.clock() - 20
  end
  return false
end

function M.onVehicleStateRestored(token, objectId, succeeded)
  local restored, vehicleId = World.finishStateRestore(token, objectId, succeeded == true)
  if not vehicleId then return false end
  if not restored then
    lastMessage = "Сохранённое состояние не удалось применить к этому игровому объекту. Машина оставлена в гараже; запись не удалена."
    publish()
    return false
  end
  if state and state.pendingRepair and state.pendingRepair.vehicleId == vehicleId then
    return resumeRepairOnObject(vehicleId, tonumber(objectId))
  end
  lastMessage = "Физическое состояние автомобиля восстановлено."
  publish()
  return true
end

function M.onRepairResult(token, objectId, succeeded, resultCode)
  loadCareer()
  if not state or type(state.pendingRepair) ~= "table" or state.pendingRepair.token ~= token then return false end
  if succeeded == true then return finalizeRepair(token, objectId) end
  if resultCode == "rejected" then return cancelRejectedRepair(token, objectId) end
  return false
end

function M.onExtensionLoaded()
  loadCareer()
  if not state then
    publish()
    return
  end

  if state.pendingStore then
    local pending = state.pendingStore
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      finalizeStore(pending.token, pending.objectId)
    elseif World.objectExists(pending.objectId) then
      World.adopt(pending.vehicleId, pending.objectId)
      World.queueStateSave(pending.objectId, pending.stateFile, pending.token, "store")
      pendingStoreStartedAt = os.clock()
    else
      cancelStore("Сохранение в гараж прервано до проверенной записи. Предыдущая конфигурация автомобиля сохранена.")
    end
  end

  if state.pendingRepair then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if pending.phase == "checkpoint" then
      if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
        local id = World.objectExists(pending.objectId) and pending.objectId or nil
        if id then World.adopt(pending.vehicleId, id) end
        resumeRepairOnObject(pending.vehicleId, id)
      elseif World.objectExists(pending.objectId) then
        World.adopt(pending.vehicleId, pending.objectId)
        World.queueStateSave(pending.objectId, pending.preStateFile, pending.token, "repair_checkpoint")
        pendingRepairStartedAt = os.clock()
      else
        cancelPendingRepair("Checkpoint не был записан, игровой объект потерян. Ремонт отменён без списания.")
      end
    elseif pending.phase == "reset" then
      if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
        finalizeRepair(pending.token, pending.objectId)
      elseif World.objectExists(pending.objectId) then
        World.adopt(pending.vehicleId, pending.objectId)
        if not World.isRestoring(pending.vehicleId) then
          World.queueRepair(pending.objectId, pending.token, pending.postStateFile)
        end
        pendingRepairStartedAt = os.clock()
      else
        pendingRepairStartedAt = nil
        lastMessage = "Ремонт ожидает восстановления той же машины из гаража. Баланс пока не изменён."
      end
    end
  end
  publish()
end

function M.onVehicleDestroyed(id)
  World.onVehicleDestroyed(id)
  local objectId = tonumber(id)
  if state and state.pendingStore and state.pendingStore.objectId == objectId then
    local pending = state.pendingStore
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      finalizeStore(pending.token, objectId)
    else
      cancelStore("Автомобиль исчез до подтверждённого сохранения. Предыдущая запись гаража сохранена.")
    end
    return
  end
  if state and state.pendingRepair and state.pendingRepair.objectId == objectId then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if pending.phase == "checkpoint" then
      if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
        resumeRepairOnObject(pending.vehicleId, nil)
      else
        cancelPendingRepair("Игровой объект исчез до сохранения checkpoint. Деньги не списаны.")
      end
    elseif vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
      finalizeRepair(pending.token, objectId)
    else
      lastMessage = "Игровой объект исчез во время ремонта. Списание отложено до восстановления машины и подтверждённого результата."
      publish()
    end
    return
  end
  publish()
end

function M.onUpdate()
  World.onUpdate()
  if not state then return end
  local now = os.clock()

  if state.pendingStore then
    local pending = state.pendingStore
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      if not storeAckRetryAt or now >= storeAckRetryAt then
        finalizeStore(pending.token, pending.objectId)
      end
    elseif not pendingStoreStartedAt or now - pendingStoreStartedAt >= 20 then
      if World.objectExists(pending.objectId) then
        World.adopt(pending.vehicleId, pending.objectId)
        World.queueStateSave(pending.objectId, pending.stateFile, pending.token, "store")
        pendingStoreStartedAt = now
      else
        cancelStore("Объект автомобиля потерян до сохранения. Предыдущее сохранение гаража не изменено.")
      end
    end
  end

  if state.pendingRepair then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if pending.phase == "checkpoint" then
      if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
        local id = World.getObjectId(pending.vehicleId)
        resumeRepairOnObject(pending.vehicleId, id)
      elseif not pendingRepairStartedAt or now - pendingRepairStartedAt >= 20 then
        if World.objectExists(pending.objectId) then
          World.adopt(pending.vehicleId, pending.objectId)
          World.queueStateSave(pending.objectId, pending.preStateFile, pending.token, "repair_checkpoint")
          pendingRepairStartedAt = now
        else
          cancelPendingRepair("Checkpoint ремонта не подтверждён и игровой объект потерян. Деньги не списаны.")
        end
      end
    elseif pending.phase == "reset" then
      if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
        if not repairAckRetryAt or now >= repairAckRetryAt then
          finalizeRepair(pending.token, pending.objectId)
        end
      elseif not World.isRestoring(pending.vehicleId) then
        local mappedId = World.getObjectId(pending.vehicleId)
        if mappedId and mappedId ~= tonumber(pending.objectId) then
          resumeRepairOnObject(pending.vehicleId, mappedId)
        elseif pendingRepairStartedAt and now - pendingRepairStartedAt >= 20 then
          if World.objectExists(pending.objectId) then
            World.queueRepair(pending.objectId, pending.token, pending.postStateFile)
            pendingRepairStartedAt = now
          else
            pendingRepairStartedAt = nil
          end
        end
      end
    end
  end

  if lastStoreAck and storeAckRetryAt and now >= storeAckRetryAt then
    finalizeStore(lastStoreAck.token, lastStoreAck.objectId)
    storeAckRetryAt = now + 1
  end
  if lastRepairAck and repairAckRetryAt and now >= repairAckRetryAt then
    finalizeRepair(lastRepairAck.token, lastRepairAck.objectId)
    repairAckRetryAt = now + 1
  end
end

return M
