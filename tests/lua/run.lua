package.path = "lua/ge/extensions/?.lua;lua/ge/extensions/?/init.lua;" .. package.path

local Career = require("perekup/career")
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
  { key = "town.1", model_key = "car_a", Configuration = "Town" },
  { key = "town.sport", model_key = "car_a", Configuration = "Town Sport" },
  { key = "road.base", model_key = "car_b", Configuration = "Road" },
  { key = "van.base", model_key = "van_c", Configuration = "Utility" },
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
  equal(state.vehicles[1].modelKey, "car_a")
  truthy(Career.isValidState(state))
end)

local purchaseListing
for _, listing in ipairs(state.listings) do
  if listing.status == "available" then purchaseListing = listing end
end
truthy(purchaseListing, "expected an available listing")

test("purchase debits once and creates a garage record", function()
  local before = state.money
  local ok = Career.buy(state, purchaseListing.id)
  truthy(ok)
  equal(state.money, before - purchaseListing.price)
  equal(#state.vehicles, 2)
  equal(state.vehicles[2].status, "owned")
  local afterFirstPurchase = state.money
  local duplicate = Career.buy(state, purchaseListing.id)
  equal(duplicate, false)
  equal(state.money, afterFirstPurchase)
end)

local bought = state.vehicles[2]
test("repair has a visible fixed price and cannot be repeated", function()
  local before = state.money
  local ok = Career.repair(state, bought.id)
  truthy(ok)
  equal(state.money, before - 75)
  equal(bought.condition, 70)
  equal(bought.repairCost, 75)
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

test("advancing a day refreshes offers without listing owned vehicles", function()
  local previousDay = state.day
  truthy(Career.advanceDay(state, configs))
  equal(state.day, previousDay + 1)
  for _, listing in ipairs(state.listings) do
    equal(listing.modelKey == starter.modelKey and listing.configKey == starter.configKey, false)
  end
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

test("BeamNG adapter exposes a complete career loop through the documented bridge", function()
  local files = {}
  local lastEvent
  FS = {
    fileExists = function(_, path) return files[path] ~= nil end,
    fileSize = function(_, path) return files[path] and 128 or 0 end,
    directoryExists = function() return true end,
    directoryCreate = function() return true end
  }
  jsonReadFile = function(path) return Career.copy(files[path]) end
  jsonWriteFile = function(path, data)
    files[path] = Career.copy(data)
    return true
  end
  core_vehicles = {
    getModelList = function(asArray)
      equal(asArray, true)
      return { models = rawModels }
    end,
    getConfigList = function(asArray)
      equal(asArray, true)
      return { configs = rawConfigs }
    end
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

  truthy(GameCore.startCareer(lastEvent.starterOptions[1].id))
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, 500)
  local firstListing = lastEvent.career.listings[1]
  truthy(firstListing)
  truthy(GameCore.buyListing(firstListing.id))
  local boughtId = lastEvent.career.vehicles[2].id
  local afterPurchase = lastEvent.career.money
  equal(GameCore.buyListing(firstListing.id), false)
  equal(lastEvent.career.money, afterPurchase)
  truthy(GameCore.repairVehicle(boughtId))
  truthy(GameCore.listVehicle(boughtId))
  local salePrice = lastEvent.career.vehicles[2].askingPrice
  truthy(GameCore.sellVehicle(boughtId))
  equal(lastEvent.career.money, afterPurchase - 75 + salePrice)
  equal(lastEvent.career.vehicles[2].status, "sold")
  truthy(files[Storage.SAVE_PATH])

  package.loaded["perekup_core"] = nil
  local ReloadedCore = require("perekup_core")
  ReloadedCore.onExtensionLoaded()
  truthy(ReloadedCore.requestSnapshot())
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, files[Storage.SAVE_PATH].money)
  equal(lastEvent.career.history[#lastEvent.career.history].kind, "sale")
end)

print(string.format("%d Lua tests passed", testsRun))
