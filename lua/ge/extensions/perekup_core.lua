local Career = require("perekup/career")
local Economy = require("perekup/economy")
local Garage = require("perekup/garage")
local Storage = require("perekup/persistence")
local Vehicles = require("perekup/vehicles")
local World = require("perekup/world")

local M = {}
-- Only this monotonically increasing generation survives a GE Lua reload.
-- Object IDs, object references and callback proofs are never extension state.
M.state = { runtimeGeneration = 0 }
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

local function startRuntimeGeneration()
  local previousState = type(M.state) == "table" and tonumber(M.state.runtimeGeneration) or 0
  local previousGlobal = tonumber(rawget(_G, "__perekup_core_runtime_generation")) or 0
  if previousState < 0 or previousState ~= math.floor(previousState) then previousState = 0 end
  if previousGlobal < 0 or previousGlobal ~= math.floor(previousGlobal) then previousGlobal = 0 end
  local generation = math.max(previousState, previousGlobal) + 1
  rawset(_G, "__perekup_core_runtime_generation", generation)
  M.state = { runtimeGeneration = generation }
  World.beginRuntime(generation)
end

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

local function resumeRepairOnObject(vehicleId, objectId, bindingProof)
  if not state or not state.pendingRepair or state.pendingRepair.vehicleId ~= vehicleId then return false end
  if not World.isBound(vehicleId, objectId, bindingProof) then
    return failure("Ремонт остановлен: принадлежность физического объекта этой машине не подтверждена.")
  end
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
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить связь незавершённого ремонта с новой игровой машиной. Баланс не изменён.")
  end
  state = candidate
  pendingRepairStartedAt = os.clock()
  pendingStateRetryAt = os.clock() + 20
  local queued, _, err = World.queueRepair(vehicleId, token, state.pendingRepair.postStateFile)
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

  local configSnapshot, configError = World.captureVehicleConfig(vehicleId, vehicle.modelKey)
  if not configSnapshot then return failure(configError) end
  local operationNumber = tonumber(state.nextOperationNumber) or 1
  local token = "R" .. tostring(operationNumber)
  local preStateFile, prePathError = World.makeStatePath(vehicle.id, token, "pre")
  if not preStateFile then return failure(prePathError) end
  local postStateFile, postPathError = World.makeStatePath(vehicle.id, token, "post")
  if not postStateFile then return failure(postPathError) end

  local candidate = Career.copy(state)
  local started, tokenOrError = Career.beginPhysicalRepair(
    candidate, vehicleId, configSnapshot, preStateFile, postStateFile)
  if not started then return failure(tokenOrError) end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить резерв операции. Ремонт не запущен.")
  end
  state = candidate
  pendingRepairStartedAt = os.clock()
  lastRepairAck = nil
  repairAckRetryAt = nil
  pendingStateRetryAt = os.clock() + 20
  local queued, _, queueError = World.queueStateSave(vehicleId, preStateFile, tokenOrError, "repair_checkpoint")
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
  local spawned, spawnResult, restoreToken, bindingProof = World.spawn(vehicleId, config, configSnapshot, stateFile)
  if not spawned then return failure(spawnResult) end
  local spawnedObjectId = tonumber(spawnResult)
  if repairResume and not restoreToken then
    if not resumeRepairOnObject(vehicleId, spawnedObjectId, bindingProof) then return true end
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

  local prepared, prepareError = World.prepareForStateSave(vehicleId)
  if not prepared then return failure(prepareError) end
  local configSnapshot, configError = World.captureVehicleConfig(vehicleId, vehicle.modelKey)
  if not configSnapshot then return failure(configError) end
  local operationNumber = tonumber(state.nextOperationNumber) or 1
  local token = "S" .. tostring(operationNumber)
  local stateFile, pathError = World.makeStatePath(vehicle.id, token, "state")
  if not stateFile then return failure(pathError) end

  local candidate = Career.copy(state)
  local started, tokenOrError = Career.beginVehicleStore(candidate, vehicleId, configSnapshot, stateFile)
  if not started then return failure(tokenOrError) end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить резерв операции. Игровой объект оставлен в мире.")
  end
  state = candidate
  pendingStoreStartedAt = os.clock()
  lastStoreAck = nil
  storeAckRetryAt = nil
  pendingStateRetryAt = os.clock() + 20
  local queued, _, queueError = World.queueStateSave(vehicleId, stateFile, tokenOrError, "store")
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

local function finalizeStore(token)
  if not state or type(state.pendingStore) ~= "table" or state.pendingStore.token ~= token then return false end
  local pending = state.pendingStore
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if not vehicle or not World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
    return false
  end

  local hadConfirmedBinding = World.isInWorld(vehicle.id)
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
  local message = hadConfirmedBinding
    and "Проверенный checkpoint сохранён; подтверждённый объект этой сессии возвращён в гараж."
    or "Проверенный checkpoint сохранён в карьеру. Объект прошлой сессии не тронут; удалите возможную старую машину вручную перед повторным выводом."
  local saved = commit(candidate, message)
  if saved then
    clearStoreRuntime()
  else
    lastStoreAck = { token = token }
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

local function finalizeRepair(token)
  if not state or type(state.pendingRepair) ~= "table" then return false end
  local pending = state.pendingRepair
  if pending.token ~= token or pending.phase ~= "reset" then return false end
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if not vehicle or not World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
    return false
  end
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
    lastRepairAck = { token = token, succeeded = true }
    repairAckRetryAt = os.clock() + 1
  end
  return saved
end

local function cancelRejectedRepair(token)
  if not state or type(state.pendingRepair) ~= "table" then return false end
  local pending = state.pendingRepair
  if pending.token ~= token or pending.phase ~= "reset" then return false end
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
    return finalizeRepair(token)
  end
  local candidate = Career.copy(state)
  local ok = Career.cancelPhysicalRepair(candidate, token)
  if not ok then return false end
  local saved = commit(candidate, "Игровой объект отклонил reset до его запуска. Деньги не списаны.")
  if saved then clearRepairRuntime() end
  return saved
end

function M.onVehicleStateSaved(token, objectId, kind, succeeded, bindingProof)
  loadCareer()
  local id = tonumber(objectId)
  if not state then return false end

  if kind == "store" and type(state.pendingStore) == "table" and state.pendingStore.token == token then
    local pending = state.pendingStore
    if not World.isCurrentOperation(pending.vehicleId, id, bindingProof, token, "store") then return false end
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      return finalizeStore(token)
    end
    if succeeded == false then
      return cancelStore("Физическое сохранение не прошло проверку. Предыдущая запись автомобиля сохранена; объект не изменён.")
    end
    pendingStoreStartedAt = os.clock() - 20
    return false
  end

  if kind == "repair_checkpoint" and type(state.pendingRepair) == "table"
    and state.pendingRepair.token == token and state.pendingRepair.phase == "checkpoint" then
    local pending = state.pendingRepair
    if not World.isCurrentOperation(pending.vehicleId, id, bindingProof, token, "repair_checkpoint") then return false end
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
      return resumeRepairOnObject(pending.vehicleId, id, bindingProof)
    end
    if succeeded == false then
      return cancelPendingRepair("Исходный физический checkpoint не прошёл проверку. Ремонт отменён без списания.")
    end
    pendingStateRetryAt = os.clock() - 20
  end
  return false
end

function M.onVehicleStateRestored(token, objectId, succeeded, bindingProof)
  local restored, vehicleId = World.finishStateRestore(token, objectId, bindingProof, succeeded == true)
  if not vehicleId then return false end
  if not restored then
    lastMessage = "Сохранённое состояние не удалось применить к подтверждённому объекту. Этот объект удалён только по текущей временной связи; запись карьеры сохранена."
    publish()
    return false
  end
  if state and state.pendingRepair and state.pendingRepair.vehicleId == vehicleId then
    return resumeRepairOnObject(vehicleId, tonumber(objectId), bindingProof)
  end
  lastMessage = "Физическое состояние автомобиля восстановлено."
  publish()
  return true
end

function M.onRepairResult(token, objectId, succeeded, resultCode, bindingProof)
  loadCareer()
  if not state or type(state.pendingRepair) ~= "table" or state.pendingRepair.token ~= token then return false end
  local pending = state.pendingRepair
  if not World.isCurrentOperation(pending.vehicleId, tonumber(objectId), bindingProof, token, "repair") then return false end
  if succeeded == true then return finalizeRepair(token) end
  if resultCode == "rejected" then return cancelRejectedRepair(token) end
  return false
end

function M.onExtensionLoaded()
  startRuntimeGeneration()
  loadCareer()
  if not state then
    publish()
    return
  end

  if state.pendingStore then
    local pending = state.pendingStore
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    local objectId = vehicle and World.getObjectId(vehicle.id) or nil
    if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
      finalizeStore(pending.token)
    elseif objectId then
      World.queueStateSave(vehicle.id, pending.stateFile, pending.token, "store")
      pendingStoreStartedAt = os.clock()
    else
      cancelStore("После загрузки не найден подтверждённый объект сохранения. Предыдущие данные карьеры сохранены; возможные старые объекты не тронуты, удалите их вручную перед повторным выводом.")
    end
  end

  if state.pendingRepair then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    local objectId = vehicle and World.getObjectId(vehicle.id) or nil
    local proof = vehicle and World.getBindingToken(vehicle.id) or nil
    if pending.phase == "checkpoint" then
      if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
        if objectId and proof then
          resumeRepairOnObject(vehicle.id, objectId, proof)
        else
          pendingRepairStartedAt = nil
          lastMessage = "Исходный checkpoint сохранён. Старый игровой ID не используется; восстановите эту карьерную машину кнопкой «Вывести в мир»."
        end
      elseif objectId and proof then
        World.queueStateSave(vehicle.id, pending.preStateFile, pending.token, "repair_checkpoint")
        pendingRepairStartedAt = os.clock()
      else
        cancelPendingRepair("Исходный checkpoint не подтверждён, а объект прошлой сессии не привязан. Ремонт отменён без списания.")
      end
    elseif pending.phase == "reset" then
      if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
        finalizeRepair(pending.token)
      elseif objectId and proof then
        World.queueRepair(vehicle.id, pending.token, pending.postStateFile)
        pendingRepairStartedAt = os.clock()
      else
        pendingRepairStartedAt = nil
        lastMessage = "Результат reset ещё не подтверждён. Старый игровой ID не используется; выведите эту карьерную машину для безопасного восстановления. Баланс не изменён."
      end
    end
  end
  publish()
end

function M.onVehicleDestroyed(id)
  local affected = World.onVehicleDestroyed(id)
  if not state then return end
  for _, binding in ipairs(affected or {}) do
    local operation = binding.operation
    if type(operation) == "table" and state.pendingStore
      and state.pendingStore.vehicleId == binding.careerVehicleId
      and state.pendingStore.token == operation.token and operation.kind == "store" then
      local pending = state.pendingStore
      local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
      if vehicle and World.validateStateFile(pending.stateFile, vehicle.modelKey, pending.configSnapshot) then
        finalizeStore(pending.token)
      else
        cancelStore("Подтверждённый объект исчез до записи checkpoint. Предыдущие данные карьеры сохранены.")
      end
    elseif type(operation) == "table" and state.pendingRepair
      and state.pendingRepair.vehicleId == binding.careerVehicleId
      and state.pendingRepair.token == operation.token then
      local pending = state.pendingRepair
      local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
      if operation.kind == "repair_checkpoint" and pending.phase == "checkpoint" then
        if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
          pendingRepairStartedAt = nil
          lastMessage = "Checkpoint ремонта сохранён. Старый объект больше не используется; восстановите карьерную машину из гаража."
        else
          cancelPendingRepair("Объект исчез до подтверждения checkpoint. Ремонт отменён без списания.")
        end
      elseif operation.kind == "repair" and pending.phase == "reset" then
        if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
          finalizeRepair(pending.token)
        else
          pendingRepairStartedAt = nil
          lastMessage = "Игровой объект ремонта исчез. Транзакция ждёт восстановления из исходного checkpoint; баланс не изменён."
        end
      end
    end
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
        finalizeStore(pending.token)
      end
    elseif not pendingStoreStartedAt or now - pendingStoreStartedAt >= 20 then
      local objectId = World.getObjectId(pending.vehicleId)
      if objectId then
        World.queueStateSave(pending.vehicleId, pending.stateFile, pending.token, "store")
        pendingStoreStartedAt = now
      else
        cancelStore("Подтверждённый объект исчез до записи checkpoint. Предыдущие данные карьеры сохранены.")
      end
    end
  end

  if state.pendingRepair then
    local pending = state.pendingRepair
    local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
    local objectId = World.getObjectId(pending.vehicleId)
    local proof = World.getBindingToken(pending.vehicleId)
    if pending.phase == "checkpoint" then
      if vehicle and World.validateStateFile(pending.preStateFile, vehicle.modelKey, pending.configSnapshot) then
        if objectId and proof and (not pendingRepairStartedAt or now - pendingRepairStartedAt >= 1) then
          pendingRepairStartedAt = now
          resumeRepairOnObject(pending.vehicleId, objectId, proof)
        end
      elseif not pendingRepairStartedAt or now - pendingRepairStartedAt >= 20 then
        if objectId and proof then
          World.queueStateSave(pending.vehicleId, pending.preStateFile, pending.token, "repair_checkpoint")
          pendingRepairStartedAt = now
        else
          cancelPendingRepair("Checkpoint ремонта не подтверждён, подтверждённый объект отсутствует. Деньги не списаны.")
        end
      end
    elseif pending.phase == "reset" then
      if vehicle and World.validateStateFile(pending.postStateFile, vehicle.modelKey, pending.configSnapshot) then
        if not repairAckRetryAt or now >= repairAckRetryAt then finalizeRepair(pending.token) end
      elseif objectId and proof and not World.isRestoring(pending.vehicleId)
        and pendingRepairStartedAt and now - pendingRepairStartedAt >= 20 then
        World.queueRepair(pending.vehicleId, pending.token, pending.postStateFile)
        pendingRepairStartedAt = now
      elseif not objectId then
        pendingRepairStartedAt = nil
      end
    end
  end

  if lastStoreAck and storeAckRetryAt and now >= storeAckRetryAt then
    finalizeStore(lastStoreAck.token)
    storeAckRetryAt = now + 1
  end
  if lastRepairAck and repairAckRetryAt and now >= repairAckRetryAt then
    finalizeRepair(lastRepairAck.token)
    repairAckRetryAt = now + 1
  end
end

return M
