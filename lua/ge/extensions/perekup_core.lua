local Career = require("perekup/career")
local Storage = require("perekup/persistence")
local Vehicles = require("perekup/vehicles")

local M = {}
local store = Storage.new()
local state
local loadError
local loadWarning
local lastMessage
local loadAttempted = false

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
    if not catalogError then
      for _, vehicle in ipairs(result.career.vehicles) do
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

local function mutate(action, successMessage)
  loadCareer()
  if loadError then
    return failure(loadError)
  end
  if not state then
    return failure("Сначала начните новую карьеру.")
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
  return commit(candidate, "Карьера начата. На балансе $500.")
end

function M.buyListing(listingId)
  return mutate(function(candidate)
    return Career.buy(candidate, listingId)
  end, "Автомобиль куплен и добавлен в гараж.")
end

function M.repairVehicle(vehicleId)
  return mutate(function(candidate)
    return Career.repair(candidate, vehicleId)
  end, "Ремонт оплачен и выполнен.")
end

function M.listVehicle(vehicleId)
  return mutate(function(candidate)
    return Career.listForSale(candidate, vehicleId)
  end, "Автомобиль выставлен на продажу.")
end

function M.sellVehicle(vehicleId)
  return mutate(function(candidate)
    return Career.sell(candidate, vehicleId)
  end, "Продажа записана. Баланс обновлён.")
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
end

return M
