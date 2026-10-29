package.path = "lua/ge/extensions/?.lua;lua/ge/extensions/?/init.lua;" .. package.path

local Career = require("perekup/career")
local Economy = require("perekup/economy")
local Storage = require("perekup/persistence")
local Vehicles = require("perekup/vehicles")

local testsRun = 0

local function equal(actual, expected, message)
  assert(actual == expected, (message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function truthy(value, message)
  assert(value, message or "expected a truthy value")
end

local function test(name, callback)
  callback()
  testsRun = testsRun + 1
  print("PASS " .. name)
end

local rawModels = {
  { key = "car_b", Brand = "Brand B", Name = "Road", Type = "Car" },
  { key = "car_a", Brand = "Brand A", Name = "Town", Type = "Car" },
  { key = "van_c", Brand = "Brand C", Name = "Van", Type = "Truck" },
  { key = "prop_box", Brand = "Prop", Name = "Box", Type = "Prop" },
  { key = "bad key", Brand = "Bad", Name = "Key", Type = "Car" },
  { key = "trailer", Brand = "Tow", Name = "Trailer", Type = "Trailer" }
}
local rawConfigs = {
  { key = "town.1", model_key = "car_a", Configuration = "Town", ["Config Type"] = "Factory", Value = 21000, Power = 90, Weight = 1200, ["Performance Class"] = 2 },
  { key = "town.sport", model_key = "car_a", Configuration = "Town Sport", ["Config Type"] = "Race", Value = 45000, Power = 300, Weight = 1350, ["Performance Class"] = 6 },
  { key = "road.base", model_key = "car_b", Configuration = "Road", ["Config Type"] = "Factory", Value = 18000, Power = 110, Weight = 1450, ["Performance Class"] = 3 },
  { key = "van.base", model_key = "van_c", Configuration = "Utility", ["Config Type"] = "Factory", Value = 32000, Power = 160, Weight = 2800, ["Performance Class"] = 2 },
  { key = "prop.base", model_key = "prop_box", Configuration = "Box" },
  { key = "orphan.base", model_key = "missing_model", Configuration = "Missing" }
}
local configs = Vehicles.discover(rawModels, rawConfigs)

test("catalog joins installed configurations to supported models and ignores props", function()
  equal(#configs, 4)
  equal(configs[1].modelKey, "car_a")
  equal(configs[1].configKey, "town.1")
  equal(configs[2].modelKey, "car_a")
  equal(configs[3].modelKey, "car_b")
  equal(configs[4].modelKey, "van_c")
  equal(#Vehicles.discover(rawModels, nil), 0)
end)

test("catalog rejects missing and non-road categories", function()
  local candidates = Vehicles.discover({
    { key = "no_type", Name = "Untyped" },
    { key = "other", Name = "Other", Type = "Utility" },
    { key = "automation", Name = "Automation", Type = "Automation" },
    { key = "trailer", Name = "Trailer", Type = "Trailer" },
    { key = "target", Name = "Target", Type = "Car" }
  }, {
    { key = "a", model_key = "no_type", Configuration = "Untyped" },
    { key = "b", model_key = "other", Configuration = "Other" },
    { key = "c", model_key = "automation", Configuration = "Automation" },
    { key = "d", model_key = "trailer", Configuration = "Trailer" },
    { key = "e", model_key = "target", Configuration = "Target" }
  })
  equal(#candidates, 1)
  equal(candidates[1].modelKey, "target")
end)

test("market prices use configuration value metadata and avoid implausible low prices", function()
  local sport = configs[2]
  equal(Economy.referenceValue(sport), 45000)
  truthy(Economy.listingPrice(sport, 1, 35) >= 2000)
  equal(Economy.hasDeclaredValue(sport), true)
  local missingValue = { type = "car", modelKey = "unknown", configKey = "base" }
  truthy(Economy.referenceValue(missingValue) >= 4000)
  equal(Economy.hasDeclaredValue(missingValue), false)
end)

test("UI token stays safe when a third-party configuration key contains quotes", function()
  local unusual = Vehicles.discover(
    { { key = "safe_car", Brand = "Test", Name = "Car", Type = "Car" } },
    { { key = "trim'one", model_key = "safe_car", Configuration = "Trim" } }
  )
  equal(#unusual, 1)
  truthy(unusual[1].id:match("^[A-Za-z0-9_-]+$"))
  equal(unusual[1].configKey, "trim'one")
  local unusualCareer = Career.start(unusual[1], unusual)
  truthy(unusualCareer)
  truthy(Career.isValidState(unusualCareer))
end)

test("starter selection gracefully returns fewer than three catalog entries", function()
  local options = Vehicles.starterOptions({ configs[1] })
  equal(#options, 1)
  equal(options[1].modelKey, "car_a")
  local oneCarCareer = Career.start(configs[1], { configs[1] })
  truthy(oneCarCareer)
  equal(#oneCarCareer.listings, 1)
  equal(oneCarCareer.listings[1].configKey, configs[1].configKey)
end)

local starter = Vehicles.starterOptions(configs)[1]
local state, startError = Career.start(starter, configs)
truthy(state, startError)

test("career starts with 500 dollars and a dynamic starter vehicle", function()
  equal(state.money, 500)
  equal(state.day, 1)
  equal(state.vehicles[1].modelKey, starter.modelKey)
  truthy(Career.isValidState(state))
end)

test("starter vehicle can fund the first used-car purchase", function()
  local starterVehicle = state.vehicles[1]
  truthy(Career.listForSale(state, starterVehicle.id))
  truthy(Career.sell(state, starterVehicle.id))
  truthy(state.money > 500, "selling the starter car should create working capital")
end)

local purchaseListing
for _, listing in ipairs(state.listings) do
  if listing.status == "available" and listing.price <= state.money
    and (not purchaseListing or listing.price < purchaseListing.price) then
    purchaseListing = listing
  end
end
truthy(purchaseListing, "expected at least one listing affordable after selling the starter")

test("purchase debits once and creates a garage record", function()
  local before = state.money
  local ok, err = Career.buy(state, purchaseListing.id)
  truthy(ok, err)
  equal(state.money, before - purchaseListing.price)
  equal(#state.vehicles, 2)
  equal(state.vehicles[2].status, "owned")
  local afterFirstPurchase = state.money
  local duplicate = Career.buy(state, purchaseListing.id)
  equal(duplicate, false)
  equal(state.money, afterFirstPurchase)
end)

local bought = state.vehicles[2]
test("repair quote scales with vehicle value, restores estimated condition and cannot repeat", function()
  local before = state.money
  local cost = Economy.repairCost(bought)
  truthy(cost >= 75)
  local ok = Career.repair(state, bought.id)
  truthy(ok)
  equal(state.money, before - cost)
  equal(bought.condition, 100)
  equal(bought.repairCost, cost)
  local afterRepair = state.money
  local duplicate = Career.repair(state, bought.id)
  equal(duplicate, false)
  equal(state.money, afterRepair)
end)

test("listing and sale update balance once and record realized profit", function()
  truthy(Career.listForSale(state, bought.id))
  equal(bought.status, "for_sale")
  truthy(bought.askingPrice > 0)
  equal(Career.listForSale(state, bought.id), false)
  local before = state.money
  truthy(Career.sell(state, bought.id))
  equal(state.money, before + bought.askingPrice)
  equal(bought.status, "sold")
  equal(bought.profit, bought.askingPrice - bought.purchasePrice - bought.repairCost)
  local afterSale = state.money
  equal(Career.sell(state, bought.id), false)
  equal(state.money, afterSale)
end)

test("advancing a day refreshes offers and permits independent copies of a configuration", function()
  local previousDay = state.day
  truthy(Career.advanceDay(state, configs))
  equal(state.day, previousDay + 1)
  local sameConfigAvailable = false
  for _, listing in ipairs(state.listings) do
    if listing.modelKey == starter.modelKey and listing.configKey == starter.configKey then
      sameConfigAvailable = true
    end
  end
  truthy(sameConfigAvailable)
  truthy(Career.isValidState(state))
end)

test("save schema retains an owned record when its model is missing", function()
  local missingModelSave = Career.copy(state)
  equal(Vehicles.findConfig({}, missingModelSave.vehicles[1].modelKey, missingModelSave.vehicles[1].configKey), nil)
  equal(missingModelSave.vehicles[1].displayName, starter.displayName)
  truthy(Career.isValidState(missingModelSave))
  local corrupted = Career.copy(missingModelSave)
  corrupted.money = -1
  equal(Career.isValidState(corrupted), false)
end)

local function memoryStore()
  local files = {}
  local rejectPrimaryWrite = false
  local adapter = {
    prepare = function() return true end,
    exists = function(path) return files[path] ~= nil end,
    read = function(path) return Career.copy(files[path]) end,
    write = function(path, value)
      if rejectPrimaryWrite and path == Storage.SAVE_PATH then return false end
      files[path] = Career.copy(value)
      return true
    end
  }
  return files, adapter, function(value) rejectPrimaryWrite = value end
end

test("storage verifies writes and restores a valid backup after primary corruption", function()
  local files, adapter = memoryStore()
  local store = Storage.new(adapter)
  truthy(store.save(state, nil))
  local nextState = Career.copy(state)
  nextState.money = nextState.money + 10
  truthy(store.save(nextState, state))
  equal(files[Storage.BACKUP_PATH].money, state.money)
  files[Storage.SAVE_PATH] = { schema = 99 }
  local loaded, warning = store.load()
  equal(loaded.money, state.money)
  truthy(warning)
end)

test("storage leaves current state unchanged when primary write is rejected", function()
  local files, adapter, reject = memoryStore()
  local store = Storage.new(adapter)
  truthy(store.save(state, nil))
  reject(true)
  local candidate = Career.copy(state)
  candidate.money = candidate.money + 25
  equal(store.save(candidate, state), false)
  equal(files[Storage.SAVE_PATH].money, state.money)
  equal(state.money + 25, candidate.money)
end)

test("storage blocks new careers when existing primary and backup are invalid", function()
  local files, adapter = memoryStore()
  files[Storage.SAVE_PATH] = { schema = -1 }
  files[Storage.BACKUP_PATH] = { schema = -1 }
  local loaded, err = Storage.new(adapter).load()
  equal(loaded, nil)
  truthy(err)
end)

test("vehicle repair waits for the physics reset hook before reporting success", function()
  local resetType
  local flexMeshReset = false
  local callback
  RESET_PHYSICS = 73
  obj = {
    getID = function() return 4242 end,
    requestReset = function(_, value) resetType = value end,
    resetBrokenFlexMesh = function() flexMeshReset = true end,
    queueGameEngineLua = function(_, command) callback = command end
  }
  package.loaded["perekup_repair"] = nil
  local vehicleRepair = dofile("lua/vehicle/extensions/perekup_repair.lua")
  truthy(vehicleRepair.requestRepair("R73"))
  equal(resetType, RESET_PHYSICS)
  equal(flexMeshReset, true)
  equal(callback, nil)
  vehicleRepair.onReset()
  truthy(callback)
  truthy(callback:find("onRepairResult('R73', 4242, true)", 1, true))
  callback = nil
  truthy(vehicleRepair.requestRepair("R73"))
  truthy(callback)
  truthy(callback:find("onRepairResult('R73', 4242, true)", 1, true), "completed token should resend its acknowledgement without resetting")
  equal(vehicleRepair.requestRepair("bad'token"), false)
  obj.requestReset = function() return false end
  callback = nil
  equal(vehicleRepair.requestRepair("R74"), false)
  truthy(callback)
  truthy(callback:find("onRepairResult('R74', 4242, false)", 1, true))
end)

test("BeamNG adapter exposes a complete career loop through guarded engine bridges", function()
  local files = {}
  local lastEvent
  local rejectGameSaveWrites = false
  FS = {
    fileExists = function(_, path) return files[path] ~= nil end,
    fileSize = function(_, path) return files[path] and 128 or 0 end,
    directoryExists = function() return true end,
    directoryCreate = function() return true end
  }
  jsonReadFile = function(path) return Career.copy(files[path]) end
  jsonWriteFile = function(path, data)
    if rejectGameSaveWrites then return false end
    files[path] = Career.copy(data)
    return true
  end
  local worldObjects = {}
  local nextObjectId = 100
  local activeObjectId
  local rejectSpawn = false
  getObjectByID = function(objectId)
    return worldObjects[tonumber(objectId)]
  end
  be = {
    getObjectByID = function(_, objectId) return worldObjects[tonumber(objectId)] end,
    getPlayerVehicleID = function(_, playerId)
      equal(playerId, 0)
      return activeObjectId
    end
  }
  gameplay_walk = {
    setWalkingMode = function(enabled)
      equal(enabled, true)
      activeObjectId = nil
      return true
    end
  }
  local function spawnMockVehicle(modelKey, options)
    truthy(type(modelKey) == "string")
    equal(options.autoEnterVehicle, true)
    if rejectSpawn then return nil end
    local id = nextObjectId
    nextObjectId = nextObjectId + 1
    local object = { queuedCommands = {} }
    object.getID = function() return id end
    object.queueLuaCommand = function(_, command)
      object.queuedCommands[#object.queuedCommands + 1] = command
      return true
    end
    object.delete = function()
      equal(activeObjectId == id, false, "the active player vehicle must be exited before deletion")
      worldObjects[id] = nil
      return true
    end
    worldObjects[id] = object
    if options.autoEnterVehicle then activeObjectId = id end
    return object
  end
  core_vehicles = {
    getModelList = function(asArray)
      equal(asArray, true)
      return { models = rawModels }
    end,
    getConfigList = function(asArray)
      equal(asArray, true)
      return { configs = rawConfigs }
    end,
    spawnNewVehicle = spawnMockVehicle
  }
  guihooks = {
    trigger = function(eventName, payload)
      equal(eventName, "PerekupSnapshot")
      lastEvent = payload
    end
  }
  package.loaded["perekup_core"] = nil
  local GameCore = require("perekup_core")
  GameCore.onExtensionLoaded()
  truthy(GameCore.requestSnapshot())
  equal(lastEvent.status, "new")
  equal(#lastEvent.starterOptions, 3)

  rejectSpawn = true
  equal(GameCore.startCareer(lastEvent.starterOptions[1].id), false)
  equal(lastEvent.status, "new")
  equal(files[Storage.SAVE_PATH], nil)
  rejectSpawn = false
  truthy(GameCore.startCareer(lastEvent.starterOptions[1].id))
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, 500)
  local starterId = lastEvent.career.starterVehicleId
  equal(lastEvent.career.vehicles[1].inWorld, true)
  equal(GameCore.sellVehicle(starterId), false)
  equal(lastEvent.career.money, 500)
  truthy(GameCore.returnVehicle(starterId))
  equal(lastEvent.career.vehicles[1].inWorld, false)
  truthy(GameCore.listVehicle(starterId))
  local starterSalePrice = lastEvent.career.vehicles[1].askingPrice
  truthy(GameCore.sellVehicle(starterId))
  truthy(lastEvent.career.money > 500)

  local firstListing
  for _, offer in ipairs(lastEvent.career.listings) do
    local repairQuote = Economy.repairCost({ condition = 35, marketValue = offer.marketValue })
    if offer.status == "available" and offer.price + repairQuote <= lastEvent.career.money
      and (not firstListing or offer.price < firstListing.price) then
      firstListing = offer
    end
  end
  truthy(firstListing, "expected an offer affordable with its repair reserve")
  truthy(GameCore.buyListing(firstListing.id))
  local boughtId = lastEvent.career.vehicles[2].id
  local afterPurchase = lastEvent.career.money
  equal(GameCore.buyListing(firstListing.id), false)
  equal(lastEvent.career.money, afterPurchase)

  truthy(GameCore.retrieveVehicle(boughtId))
  local firstObjectId = lastEvent.career.vehicles[2].worldObjectId
  truthy(firstObjectId)
  equal(lastEvent.career.vehicles[2].inWorld, true)
  equal(GameCore.retrieveVehicle(boughtId), false)
  equal(GameCore.listVehicle(boughtId), false)

  local repairQuote = lastEvent.career.vehicles[2].repairQuote
  local beforeRepair = lastEvent.career.money
  truthy(GameCore.repairVehicle(boughtId))
  local failedRepairToken = lastEvent.career.pendingRepair.token
  equal(lastEvent.career.money, beforeRepair)
  equal(GameCore.repairVehicle(boughtId), false)
  equal(GameCore.advanceDay(), false)
  worldObjects[firstObjectId] = nil
  GameCore.onVehicleDestroyed(firstObjectId)
  equal(lastEvent.career.pendingRepair, nil)
  equal(lastEvent.career.money, beforeRepair)
  equal(lastEvent.career.vehicles[2].repairUsed, false)
  equal(GameCore.onRepairResult(failedRepairToken, firstObjectId, true), false)

  truthy(GameCore.retrieveVehicle(boughtId))
  local objectId = lastEvent.career.vehicles[2].worldObjectId
  truthy(GameCore.repairVehicle(boughtId))
  local repairToken = lastEvent.career.pendingRepair.token
  equal(lastEvent.career.money, beforeRepair)
  local realClock = os.clock
  local fakeClock = 100
  os.clock = function() return fakeClock end
  package.loaded["perekup_core"] = nil
  local ReloadedCore = require("perekup_core")
  ReloadedCore.onExtensionLoaded()
  GameCore = ReloadedCore
  truthy(worldObjects[objectId].queuedCommands[2], "pending repair should be re-queued after extension load")
  fakeClock = 121
  GameCore.onUpdate()
  truthy(lastEvent.career.pendingRepair, "a delayed acknowledgement must not cancel a live physical repair")
  truthy(worldObjects[objectId].queuedCommands[3], "live pending repair should re-request an acknowledgement after timeout")
  rejectGameSaveWrites = true
  equal(GameCore.onRepairResult(repairToken, objectId, true), false)
  equal(lastEvent.career.money, beforeRepair)
  fakeClock = 142
  GameCore.onUpdate()
  truthy(lastEvent.career.pendingRepair, "a failed acknowledgement save must stay pending until it can be retried")
  equal(lastEvent.career.money, beforeRepair)
  rejectGameSaveWrites = false
  fakeClock = 143
  GameCore.onUpdate()
  os.clock = realClock
  equal(lastEvent.career.pendingRepair, nil)
  equal(lastEvent.career.money, beforeRepair - repairQuote)
  equal(lastEvent.career.vehicles[2].condition, 100)
  equal(lastEvent.career.vehicles[2].repairUsed, true)
  equal(GameCore.onRepairResult(repairToken, objectId, true), false)
  equal(lastEvent.career.money, beforeRepair - repairQuote)

  equal(GameCore.listVehicle(boughtId), false)
  truthy(GameCore.returnVehicle(boughtId))
  truthy(GameCore.listVehicle(boughtId))
  local salePrice = lastEvent.career.vehicles[2].askingPrice
  truthy(GameCore.sellVehicle(boughtId))
  equal(lastEvent.career.money, beforeRepair - repairQuote + salePrice)
  equal(lastEvent.career.vehicles[2].status, "sold")
  truthy(files[Storage.SAVE_PATH])

  package.loaded["perekup_core"] = nil
  ReloadedCore = require("perekup_core")
  ReloadedCore.onExtensionLoaded()
  truthy(ReloadedCore.requestSnapshot())
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, files[Storage.SAVE_PATH].money)
  equal(lastEvent.career.history[#lastEvent.career.history].kind, "sale")
  truthy(starterSalePrice > 0)
end)

print(string.format("%d Lua tests passed", testsRun))
