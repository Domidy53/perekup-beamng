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
      if not catalogError then
        vehicle.modelAvailable = Vehicles.findConfig(configs, vehicle.modelKey, vehicle.configKey) ~= nil
      end
    end
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
  local candidate = Career.copy(state)
  local ok, message = action(candidate)
  if not ok then
    return failure(message or "Действие не выполнено.")
  end
  return commit(candidate, successMessage)
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
  if state.pendingRepair then return failure("Дождитесь подтверждения текущего ремонта.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Ремонт доступен только для машины в вашем гараже.")
  end
  local objectId = World.getObjectId(vehicleId)
  if objectId == nil then
    return failure("Сначала выведите эту машину в игровой мир.")
  end

  local candidate = Career.copy(state)
  local started, tokenOrError = Career.beginPhysicalRepair(candidate, vehicleId, objectId)
  if not started then return failure(tokenOrError) end
  if not store.save(candidate, state) then
    return failure("Не удалось сохранить резерв операции. Физический ремонт не запущен.")
  end
  state = candidate
  pendingRepairStartedAt = os.clock()
  lastRepairAck = nil
  repairAckRetryAt = nil
  local queued, queueError = World.queueRepair(objectId, tokenOrError)
  if not queued then
    cancelPendingRepair("Команда ремонта не принята. Деньги не списаны.")
    return failure(queueError)
  end
  lastMessage = "Команда физического ремонта отправлена; ждём подтверждение машины."
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
  if state.pendingRepair then return failure("Дождитесь подтверждения текущего ремонта.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Эту машину нельзя вывести в игровой мир.")
  end
  local configs, catalogError = getCatalog()
  if catalogError then return failure(catalogError) end
  local config = Vehicles.findConfig(configs, vehicle.modelKey, vehicle.configKey)
  if not config then return failure("Конфигурация машины недоступна в текущей установке.") end
  local spawned, spawnError = World.spawn(vehicleId, config)
  if not spawned then return failure(spawnError) end
  lastMessage = "Машина появилась в игровом мире и передана игроку."
  publish(configs)
  return true
end

function M.returnVehicle(vehicleId)
  loadCareer()
  if loadError then return failure(loadError) end
  if not state then return failure("Сначала начните новую карьеру.") end
  if state.pendingRepair then return failure("Дождитесь подтверждения текущего ремонта.") end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return failure("Эту машину нельзя вернуть в гараж.")
  end
  local returned, err = World.returnToGarage(vehicleId)
  if not returned then return failure(err) end
  lastMessage = "Игровой объект удалён; запись о машине сохранена в гараже."
  publish()
  return true
end

local function applyRepairResult(token, objectId, succeeded)
  if not state or type(state.pendingRepair) ~= "table"
    or state.pendingRepair.token ~= token or state.pendingRepair.objectId ~= tonumber(objectId) then
    return false
  end
  local candidate = Career.copy(state)
  local ok, err
  if succeeded == true then
    ok, err = Career.completePhysicalRepair(candidate, token)
  else
    ok, err = Career.cancelPhysicalRepair(candidate, token)
  end
  if not ok then
    lastMessage = err
    publish()
    return false
  end
  local saved = commit(candidate, succeeded and "Игровой объект подтвердил полный сброс физического состояния." or "Физический ремонт не подтверждён; деньги не списаны.")
  if saved then
    pendingRepairStartedAt = nil
    lastRepairAck = nil
    repairAckRetryAt = nil
  else
    lastRepairAck = { token = token, objectId = tonumber(objectId), succeeded = succeeded == true }
    repairAckRetryAt = os.clock() + 1
  end
  return saved
end

function M.onRepairResult(token, objectId, succeeded)
  return applyRepairResult(token, objectId, succeeded)
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

function M.onExtensionLoaded()
  loadCareer()
  if state and type(state.pendingRepair) == "table" then
    local pending = state.pendingRepair
    if World.objectExists(pending.objectId) then
      local queued = World.queueRepair(pending.objectId, pending.token)
      if queued then
        pendingRepairStartedAt = os.clock()
        repairAckRetryAt = nil
      else
        pendingRepairStartedAt = os.clock() - 30
      end
    else
      cancelPendingRepair("Незавершённый ремонт отменён: игровой объект уже недоступен. Деньги не списаны.")
    end
  end
end

function M.onVehicleDestroyed(id)
  World.onVehicleDestroyed(id)
  if state and type(state.pendingRepair) == "table" and state.pendingRepair.objectId == tonumber(id) then
    applyRepairResult(state.pendingRepair.token, id, false)
  else
    publish()
  end
end

function M.onUpdate()
  if state and type(state.pendingRepair) == "table" then
    local now = os.clock()
    if lastRepairAck then
      if repairAckRetryAt and now >= repairAckRetryAt then
        applyRepairResult(lastRepairAck.token, lastRepairAck.objectId, lastRepairAck.succeeded)
      end
    elseif pendingRepairStartedAt and now - pendingRepairStartedAt > 20
      and (not repairAckRetryAt or now >= repairAckRetryAt) then
      local pending = state.pendingRepair
      if not World.objectExists(pending.objectId) then
        cancelPendingRepair("Незавершённый ремонт отменён: игровой объект уже недоступен. Деньги не списаны.")
        return
      end
      local queued = World.queueRepair(pending.objectId, pending.token)
      pendingRepairStartedAt = now
      repairAckRetryAt = nil
      if queued then
        lastMessage = "Подтверждение задерживается. Запрос проверен повторно; списание ждёт результата объекта."
      else
        lastMessage = "Нет подтверждения ремонта. Операция остаётся ожидающей, баланс не изменён."
      end
      publish()
    end
  end
end

return M
