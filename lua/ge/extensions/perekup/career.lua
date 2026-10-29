local Economy = require("perekup/economy")
local Garage = require("perekup/garage")
local Listings = require("perekup/listings")
local Progression = require("perekup/progression")
local Repair = require("perekup/repair")
local Vehicles = require("perekup/vehicles")

local M = {}
local MAX_HISTORY = 120
local MAX_BALANCE = 1000000000

local function safeId(value)
  return type(value) == "string" and #value > 0 and #value <= 128 and value:match("^[%w_%-]+$") ~= nil
end

local function integer(value, minimum, maximum)
  return type(value) == "number" and value == math.floor(value) and value >= minimum and value <= maximum
end

local function boundedText(value, maximum)
  return type(value) == "string" and #value > 0 and #value <= maximum and value:find("%z") == nil
end

local function findById(items, itemId)
  for _, item in ipairs(items or {}) do
    if item.id == itemId then
      return item
    end
  end
  return nil
end

local function record(state, kind, description, moneyDelta)
  local transactionNumber = state.nextTransactionNumber
  state.nextTransactionNumber = transactionNumber + 1
  state.history[#state.history + 1] = {
    id = "T" .. tostring(transactionNumber),
    day = state.day,
    kind = kind,
    description = description,
    amount = moneyDelta,
    balanceAfter = state.money
  }
  while #state.history > MAX_HISTORY do
    table.remove(state.history, 1)
  end
end

local function uniqueConfig(configs, configId)
  return Vehicles.findConfigById(configs, configId)
end

function M.copy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local result = {}
  seen[value] = result
  for key, child in pairs(value) do
    result[M.copy(key, seen)] = M.copy(child, seen)
  end
  return result
end

function M.start(config, configs)
  if type(config) ~= "table" or not safeId(config.id) or uniqueConfig(configs, config.id) == nil then
    return nil, "Выбранный автомобиль уже недоступен. Обновите каталог."
  end

  local state = {
    schema = 1,
    started = true,
    money = 500,
    day = 1,
    nextVehicleNumber = 2,
    nextTransactionNumber = 1,
    nextOperationNumber = 1,
    pendingRepair = nil,
    starterVehicleId = "V1",
    vehicles = {
      {
        id = "V1",
        modelKey = config.modelKey,
        configKey = config.configKey,
        configName = config.configName,
        brand = config.brand,
        name = config.modelName,
        displayName = config.displayName,
        type = config.type,
        status = "owned",
        condition = 45,
        marketValue = Economy.referenceValue(config),
        valueSource = Economy.hasDeclaredValue(config) and "metadata" or "estimate",
        purchasePrice = 0,
        repairCost = 0,
        repairUsed = false,
        askingPrice = 0
      }
    },
    listings = {},
    history = {}
  }
  state.listings = Listings.create(configs, state.day, state.vehicles)
  record(state, "start", "Начало карьеры и выбор стартового автомобиля", 0)
  return state
end

function M.buy(state, listingId)
  if not safeId(listingId) then
    return false, "Некорректное объявление."
  end
  local listing = findById(state.listings, listingId)
  if not listing or listing.status ~= "available" then
    return false, "Это объявление больше недоступно."
  end
  if not integer(listing.price, 0, MAX_BALANCE) or listing.price > state.money then
    return false, "Недостаточно денег для покупки."
  end
  if Garage.findById(state.vehicles, listing.purchasedVehicleId) then
    return false, "Эта покупка уже записана."
  end

  local number = state.nextVehicleNumber
  state.nextVehicleNumber = number + 1
  local vehicleId = "V" .. tostring(number)
  listing.status = "purchased"
  listing.purchasedVehicleId = vehicleId
  state.money = state.money - listing.price
  local vehicle = {
    id = vehicleId,
    modelKey = listing.modelKey,
    configKey = listing.configKey,
    configName = listing.configName,
    brand = listing.brand,
    name = listing.name,
    displayName = listing.displayName,
    type = listing.type,
    status = "owned",
    condition = 35,
    marketValue = listing.marketValue,
    valueSource = listing.valueSource,
    power = listing.power,
    weight = listing.weight,
    performanceClass = listing.performanceClass,
    purchasePrice = listing.price,
    repairCost = 0,
    repairUsed = false,
    askingPrice = 0,
    purchaseListingId = listing.id
  }
  if not Garage.add(state.vehicles, vehicle) then
    return false, "Автомобиль уже находится в гараже."
  end
  record(state, "purchase", "Покупка: " .. listing.displayName, -listing.price)
  return true
end

function M.repair(state, vehicleId)
  if not safeId(vehicleId) then
    return false, "Некорректный автомобиль."
  end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  local previousRepairCost = vehicle and vehicle.repairCost or 0
  local ok, err = Repair.perform(state, vehicle)
  if not ok then
    return false, err
  end
  local cost = vehicle.repairCost - previousRepairCost
  record(state, "repair", "Базовый ремонт: " .. vehicle.displayName, -cost)
  return true
end

function M.beginPhysicalRepair(state, vehicleId, objectId)
  if state.pendingRepair then
    return false, "Дождитесь завершения текущего ремонта."
  end
  if not safeId(vehicleId) or not integer(tonumber(objectId), 0, MAX_BALANCE) then
    return false, "Не удалось подтвердить игровую машину для ремонта."
  end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" or vehicle.repairUsed or vehicle.condition >= 100 then
    return false, "Эту машину сейчас нельзя ремонтировать."
  end
  local cost = Economy.repairCost(vehicle)
  if cost <= 0 or state.money < cost then
    return false, "Недостаточно денег для ремонта."
  end
  local operationNumber = tonumber(state.nextOperationNumber) or 1
  if not integer(operationNumber, 1, 9999999) then
    return false, "Достигнут предел идентификаторов операций."
  end
  state.nextOperationNumber = operationNumber + 1
  state.pendingRepair = {
    token = "R" .. tostring(operationNumber),
    vehicleId = vehicleId,
    objectId = tonumber(objectId),
    cost = cost,
    conditionAfter = Economy.repairCondition(vehicle.condition),
    repairCostAfter = vehicle.repairCost + cost
  }
  return true, state.pendingRepair.token
end

function M.completePhysicalRepair(state, token)
  local pending = state.pendingRepair
  if type(pending) ~= "table" or pending.token ~= token then
    return false, "Результат ремонта устарел или уже обработан."
  end
  local vehicle = Garage.findById(state.vehicles, pending.vehicleId)
  if not vehicle or vehicle.status ~= "owned" or vehicle.repairUsed or state.money < pending.cost then
    return false, "Состояние карьеры изменилось во время ремонта."
  end
  state.money = state.money - pending.cost
  vehicle.condition = pending.conditionAfter
  vehicle.repairCost = pending.repairCostAfter
  vehicle.repairUsed = true
  state.pendingRepair = nil
  record(state, "repair", "Физический ремонт: " .. vehicle.displayName, -pending.cost)
  return true
end

function M.cancelPhysicalRepair(state, token)
  if type(state.pendingRepair) ~= "table" or state.pendingRepair.token ~= token then
    return false, "Результат ремонта устарел или уже обработан."
  end
  state.pendingRepair = nil
  return true
end

function M.listForSale(state, vehicleId)
  if not safeId(vehicleId) then
    return false, "Некорректный автомобиль."
  end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "owned" then
    return false, "Автомобиль нельзя выставить на продажу."
  end

  vehicle.askingPrice = Economy.resalePrice(vehicle)
  vehicle.status = "for_sale"
  record(state, "listed", "Выставлено на продажу: " .. vehicle.displayName, 0)
  return true
end

function M.sell(state, vehicleId)
  if not safeId(vehicleId) then
    return false, "Некорректный автомобиль."
  end
  local vehicle = Garage.findById(state.vehicles, vehicleId)
  if not vehicle or vehicle.status ~= "for_sale" then
    return false, "Сначала выставьте автомобиль на продажу."
  end
  if not integer(vehicle.askingPrice, 0, MAX_BALANCE) or state.money + vehicle.askingPrice > MAX_BALANCE then
    return false, "Не удалось подтвердить цену продажи."
  end

  local proceeds = vehicle.askingPrice
  local profit = proceeds - vehicle.purchasePrice - vehicle.repairCost
  state.money = state.money + proceeds
  vehicle.status = "sold"
  vehicle.salePrice = proceeds
  vehicle.profit = profit
  record(state, "sale", "Продажа: " .. vehicle.displayName .. " (результат $" .. tostring(profit) .. ")", proceeds)
  return true
end

function M.advanceDay(state, configs)
  local ok, err = Progression.advanceDay(state, configs)
  if not ok then
    return false, err
  end
  record(state, "day", "Новый день: объявления обновлены", 0)
  return true
end

function M.isValidState(state)
  if type(state) ~= "table" or state.schema ~= 1 or state.started ~= true then
    return false
  end
  if not integer(state.money, 0, MAX_BALANCE) or not integer(state.day, 1, 10000000) then
    return false
  end
  if not integer(state.nextVehicleNumber, 2, 10000000) or not integer(state.nextTransactionNumber, 2, 10000000) then
    return false
  end
  if state.nextOperationNumber ~= nil and not integer(state.nextOperationNumber, 1, 10000000) then
    return false
  end
  if not safeId(state.starterVehicleId) or type(state.vehicles) ~= "table" or #state.vehicles < 1 or #state.vehicles > 500 then
    return false
  end
  if type(state.listings) ~= "table" or #state.listings > 500 or type(state.history) ~= "table" or #state.history > MAX_HISTORY then
    return false
  end

  local vehicleIds = {}
  for _, vehicle in ipairs(state.vehicles) do
    if type(vehicle) ~= "table" or not safeId(vehicle.id) or vehicleIds[vehicle.id]
      or not safeId(vehicle.modelKey) or not boundedText(vehicle.configKey, 64)
      or not boundedText(vehicle.configName, 64) or not boundedText(vehicle.displayName, 128)
      or not integer(vehicle.condition, 0, 100) or not integer(vehicle.marketValue, 0, MAX_BALANCE)
      or not integer(vehicle.purchasePrice, 0, MAX_BALANCE) or not integer(vehicle.repairCost, 0, MAX_BALANCE)
      or type(vehicle.repairUsed) ~= "boolean" or not integer(vehicle.askingPrice, 0, MAX_BALANCE)
      or (vehicle.status ~= "owned" and vehicle.status ~= "for_sale" and vehicle.status ~= "sold") then
      return false
    end
    vehicleIds[vehicle.id] = true
  end
  if not vehicleIds[state.starterVehicleId] then
    return false
  end
  if state.pendingRepair ~= nil then
    local pending = state.pendingRepair
    local vehicle = type(pending) == "table" and Garage.findById(state.vehicles, pending.vehicleId) or nil
    if type(pending) ~= "table" or not safeId(pending.token) or not safeId(pending.vehicleId)
      or not integer(pending.objectId, 0, MAX_BALANCE) or not integer(pending.cost, 75, MAX_BALANCE)
      or not integer(pending.conditionAfter, 0, 100) or not integer(pending.repairCostAfter, 0, MAX_BALANCE)
      or not vehicle or vehicle.status ~= "owned" or vehicle.repairUsed or state.money < pending.cost then
      return false
    end
  end

  local listingIds = {}
  for _, listing in ipairs(state.listings) do
    if type(listing) ~= "table" or not safeId(listing.id) or listingIds[listing.id]
      or not safeId(listing.modelKey) or not boundedText(listing.configKey, 64)
      or not boundedText(listing.configName, 64) or not boundedText(listing.displayName, 128)
      or not integer(listing.price, 0, MAX_BALANCE) or not integer(listing.marketValue, 0, MAX_BALANCE)
      or (listing.status ~= "available" and listing.status ~= "purchased") then
      return false
    end
    if listing.status == "purchased" and not vehicleIds[listing.purchasedVehicleId] then
      return false
    end
    listingIds[listing.id] = true
  end

  local historyIds = {}
  for _, entry in ipairs(state.history) do
    if type(entry) ~= "table" or not safeId(entry.id) or historyIds[entry.id]
      or not integer(entry.day, 1, 10000000) or not boundedText(entry.kind, 32)
      or not boundedText(entry.description, 256) or not integer(entry.amount, -MAX_BALANCE, MAX_BALANCE)
      or not integer(entry.balanceAfter, 0, MAX_BALANCE) then
      return false
    end
    historyIds[entry.id] = true
  end
  return true
end

return M
