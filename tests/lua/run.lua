package.path = "lua/ge/extensions/?.lua;lua/ge/extensions/?/init.lua;" .. package.path

local Career = require("perekup/career")
local Economy = require("perekup/economy")
local Storage = require("perekup/persistence")
local Vehicles = require("perekup/vehicles")
local Listings = require("perekup/listings")
local World = require("perekup/world")
local Diagnostics = require("perekup/diagnostics")

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

test("diagnostics accept only small event codes and export bounded snapshots", function()
  truthy(Diagnostics.record("test.safe_event", "ok"))
  equal(Diagnostics.record("C:/Users/player/save.json", "ok"), false,
    "free-form paths must never enter the diagnostic event list")
  local report = Diagnostics.snapshot({ career = { status = "active" } })
  equal(report.schema, 1)
  equal(report.career.career.status, "active")
  truthy(#report.events <= 100)
end)

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

test("vehicle config capture rejects malformed variables and paint data", function()
  local previous = core_vehicle_manager
  core_vehicle_manager = {
    getVehicleData = function() return { config = { model = "car_a", parts = {}, vars = "invalid" } } end
  }
  local snapshot = World.captureVehicleConfig(1, "car_a")
  equal(snapshot, nil, "malformed variables must not be silently replaced with an empty table")
  core_vehicle_manager.getVehicleData = function()
    return { config = { model = "car_a", parts = {}, vars = {}, paints = "invalid" } }
  end
  snapshot = World.captureVehicleConfig(1, "car_a")
  equal(snapshot, nil, "malformed paint data must not be silently replaced with an empty table")
  core_vehicle_manager = previous
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

test("schema three rejects persistent BeamNG object IDs", function()
  local contaminated = Career.copy(state)
  contaminated.vehicles[1].worldObjectId = 99
  equal(Career.isValidState(contaminated), false, "session IDs must stay out of persistent career records")
end)

test("starter sale always leaves a day-one offer plus its repair reserve", function()
  local config = {
    id = "reserve_test_1", modelKey = "reserve_car", configKey = "reserve.base",
    modelName = "Reserve", displayName = "Reserve", configName = "Base", type = "car",
    value = 50000000
  }
  local starterVehicle = { id = config.id, modelKey = config.modelKey, configKey = config.configKey,
    marketValue = 50000000, condition = 45 }
  for attempt = 1, 2000 do
    config.id = "reserve_test_" .. tostring(attempt)
    starterVehicle.id = config.id
    local normalPrice = Economy.listingPrice(config, 1, 35)
    local normalReserve = Economy.repairCost({ condition = 35, marketValue = 50000000 })
    local budget = 500 + Economy.resalePrice(starterVehicle)
    if normalPrice + normalReserve > budget then
      local offers = Listings.create({ config }, 1, starterVehicle)
      equal(#offers, 1)
      equal(offers[1].condition, 20)
      truthy(offers[1].price + Economy.repairCost({ condition = offers[1].condition, marketValue = offers[1].marketValue }) <= budget)
      return
    end
  end
  error("could not find a deterministic high-variance test listing")
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

test("vehicle state adapter verifies serialization, restores compatibly, and retries reset acknowledgements", function()
  local files = {}
  local callbacks = {}
  local loadCount, resetCount, saveAllowed = 0, 0, true
  local parts = { engine = "test_engine", suspension = "test_suspension" }
  local vars = { tireWidth = 0.2 }
  local function savedState()
    return {
      format = "v2", model = "test_car", vehicleDirectory = "vehicles/test_car",
      nodeCount = 2, beamCount = 1, parts = Career.copy(parts), vars = Career.copy(vars),
      hydros = {}, nodes = { [1] = { pos = { 0, 0, 0 }, mass = 1 }, [2] = { pos = { 1, 0, 0 }, mass = 1 } },
      beams = { [1] = { broken = false } }
    }
  end
  FS = { fileExists = function(_, path) return files[path] ~= nil end }
  jsonReadFile = function(path) return Career.copy(files[path]) end
  v = {
    data = { model = "test_car", vehicleDirectory = "vehicles/test_car", nodes = { 1, 2 }, beams = { 1 } },
    userPartConfig = parts,
    userVars = vars
  }
  beamstate = {
    save = function(path)
      if not saveAllowed then return false end
      files[path] = savedState()
      return true
    end,
    load = function(path)
      truthy(files[path])
      loadCount = loadCount + 1
      return true
    end
  }
  RESET_PHYSICS = 73
  local bindingProof = "B_unit_73"
  obj = {
    getID = function() return 4242 end,
    requestReset = function(_, value)
      equal(value, RESET_PHYSICS)
      resetCount = resetCount + 1
      return true
    end,
    resetBrokenFlexMesh = function() return true end,
    queueGameEngineLua = function(_, command)
      callbacks[#callbacks + 1] = command
      return true
    end
  }
  package.loaded["perekup_vehicle_state"] = nil
  local vehicleState = dofile("lua/vehicle/extensions/perekup_vehicle_state.lua")
  local statePath = "settings/perekup_vehicle_states/unit_state.json"
  truthy(vehicleState.saveState(statePath, "S73", "store", bindingProof))
  truthy(callbacks[#callbacks]:find('onVehicleStateSaved("S73", 4242, "store", true, "B_unit_73")', 1, true))
  local saveCalls = #callbacks
  truthy(vehicleState.saveState(statePath, "S73", "store", bindingProof))
  equal(#callbacks, saveCalls + 1, "a repeated save must re-ack the same verified file")
  truthy(vehicleState.restoreState(statePath, "L73", bindingProof))
  equal(loadCount, 1)
  truthy(vehicleState.restoreState(statePath, "L73", bindingProof))
  equal(loadCount, 1, "restore token replay must not load the same state twice")

  local postPath = "settings/perekup_vehicle_states/unit_repair_post.json"
  local callbacksBeforeRepair = #callbacks
  truthy(vehicleState.requestRepair("R73", postPath, bindingProof))
  equal(resetCount, 1)
  vehicleState.onReset()
  equal(#callbacks, callbacksBeforeRepair, "the reset hook schedules a post-reset save on the next vehicle update")
  vehicleState.updateGFX(0.1)
  truthy(callbacks[#callbacks]:find('onRepairResult("R73", 4242, true, "saved", "B_unit_73")', 1, true))
  truthy(vehicleState.requestRepair("R73", postPath, bindingProof))
  equal(resetCount, 1, "a completed repair token must not reset twice")

  saveAllowed = false
  truthy(vehicleState.requestRepair("R74", "settings/perekup_vehicle_states/retry_post.json", bindingProof))
  vehicleState.onReset()
  local callbackCount = #callbacks
  vehicleState.updateGFX(5)
  equal(#callbacks, callbackCount, "failed post-reset file verification must not claim success")
  saveAllowed = true
  vehicleState.updateGFX(5)
  truthy(callbacks[#callbacks]:find('onRepairResult("R74", 4242, true, "saved", "B_unit_73")', 1, true))

  obj.requestReset = function() return false end
  equal(vehicleState.requestRepair("R75", "settings/perekup_vehicle_states/rejected_post.json", bindingProof), false)
  truthy(callbacks[#callbacks]:find('onRepairResult("R75", 4242, false, "rejected", "B_unit_73")', 1, true))
end)

test("schema-one pending repair migrates without a debit when its physical checkpoint is unknown", function()
  local legacy = Career.copy(state)
  legacy.schema = 1
  legacy.nextOperationNumber = nil
  legacy.pendingStore = nil
  for _, vehicle in ipairs(legacy.vehicles) do
    vehicle.configSnapshot = nil
    vehicle.beamStateFile = nil
  end
  local quote = Economy.repairCost(legacy.vehicles[1])
  legacy.pendingRepair = {
    token = "R1", vehicleId = legacy.vehicles[1].id, objectId = 12, cost = quote,
    conditionAfter = 100, repairCostAfter = quote
  }
  legacy.money = legacy.money + quote
  local before = legacy.money
  local upgraded, changed, warning = Career.upgradeState(legacy)
  truthy(changed)
  truthy(warning)
  equal(upgraded.schema, 3)
  equal(upgraded.pendingRepair, nil)
  equal(upgraded.money, before)
  truthy(Career.isValidState(upgraded))
end)

test("BeamNG adapter rejects reused foreign IDs and recovers saves and repairs after restart", function()
  local files, lastEvent = {}, nil
  local rejectGameSaveWrites = false
  local destroyHookCore
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
  local worldObjects, nextObjectId, activeObjectId = {}, 100, nil
  local rejectSpawn, spawnCount = false, 0
  local function configSnapshot(modelKey, configKey, custom)
    if type(custom) == "table" then return Career.copy(custom) end
    return {
      format = "2", model = modelKey, licenseName = "TEST-" .. modelKey,
      parts = { engine = "engine_" .. configKey, suspension = "suspension_" .. configKey },
      vars = { tireWidth = 0.2 }, paints = { { baseColor = { 0.2, 0.3, 0.4, 1 } } }
    }
  end
  local function makeBeamstateFile(snapshot, marker)
    return {
      format = "v2", model = snapshot.model, vehicleDirectory = "vehicles/" .. snapshot.model,
      nodeCount = 2, beamCount = 1, parts = Career.copy(snapshot.parts), vars = Career.copy(snapshot.vars),
      hydros = {}, nodes = {
        [1] = { pos = { marker or 1, 0, 0 }, mass = 1 },
        [2] = { pos = { 0, marker or 1, 0 }, mass = 1 }
      }, beams = { [1] = { broken = false, marker = marker or 1 } }
    }
  end
  local function seedStateFile(path, snapshot, marker)
    files[path] = makeBeamstateFile(snapshot, marker)
  end
  local function lastSavedCareer()
    return files[Storage.SAVE_PATH]
  end
  local function newCore()
    package.loaded["perekup_core"] = nil
    local core = require("perekup_core")
    core.onExtensionLoaded()
    destroyHookCore = core
    return core
  end

  local function lookupWrapper(object)
    if not object then return nil end
    return {
      getID = function() return object.getID() end,
      getName = function() return object.name end,
      setName = function(_, name) return object.setName(object, name) end,
      queueLuaCommand = function(_, command) return object.queueLuaCommand(object, command) end,
      delete = function() return object.delete(object) end
    }
  end
  getObjectByID = function(objectId) return lookupWrapper(worldObjects[tonumber(objectId)]) end
  be = {
    getObjectByID = function(_, objectId) return lookupWrapper(worldObjects[tonumber(objectId)]) end,
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
  scenetree = {
    findObject = function(name)
      for _, object in pairs(worldObjects) do
        if object.name == name then return lookupWrapper(object) end
      end
      return nil
    end
  }
  local function spawnMockVehicle(modelKey, options)
    truthy(type(modelKey) == "string")
    equal(options.autoEnterVehicle, true)
    if rejectSpawn then return nil end
    local id = nextObjectId
    nextObjectId, spawnCount = nextObjectId + 1, spawnCount + 1
    local key = type(options.config) == "string" and options.config or "default"
    local object = { queuedCommands = {}, deleteCount = 0, config = configSnapshot(modelKey, key, options.config) }
    object.getID = function() return id end
    object.getName = function() return object.name end
    object.setName = function(_, name)
      for otherId, other in pairs(worldObjects) do
        if otherId ~= id and other.name == name then return false end
      end
      object.name = name
      return true
    end
    object.queueLuaCommand = function(_, command)
      object.queuedCommands[#object.queuedCommands + 1] = command
      return true
    end
    object.delete = function()
      equal(activeObjectId == id, false, "the player vehicle must be exited before deletion")
      object.deleteCount = object.deleteCount + 1
      worldObjects[id] = nil
      if destroyHookCore then destroyHookCore.onVehicleDestroyed(id) end
      return true
    end
    worldObjects[id] = object
    if options.autoEnterVehicle then activeObjectId = id end
    return object
  end
  local function placeForeignObject(id, modelKey, configKey)
    local foreign = { queuedCommands = {}, deleteCount = 0, config = configSnapshot(modelKey, configKey), name = "FOREIGN_" .. configKey }
    foreign.getID = function() return id end
    foreign.getName = function() return foreign.name end
    foreign.setName = function(_, name) foreign.name = name return true end
    foreign.queueLuaCommand = function(_, command)
      foreign.queuedCommands[#foreign.queuedCommands + 1] = command
      return true
    end
    foreign.delete = function()
      foreign.deleteCount = foreign.deleteCount + 1
      worldObjects[id] = nil
      return true
    end
    worldObjects[id] = foreign
    return foreign
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
  core_vehicle_manager = {
    getVehicleData = function(id)
      local object = worldObjects[tonumber(id)]
      return object and { config = Career.copy(object.config) } or nil
    end
  }
  local diagnosticsExportEvent
  guihooks = {
    trigger = function(eventName, payload)
      if eventName == "PerekupSnapshot" then
        lastEvent = payload
      elseif eventName == "PerekupDiagnosticsExported" then
        diagnosticsExportEvent = payload
      else
        error("unexpected UI event " .. tostring(eventName))
      end
    end
  }
  local function destroyObject(core, id)
    worldObjects[tonumber(id)] = nil
    if activeObjectId == tonumber(id) then activeObjectId = nil end
    core.onVehicleDestroyed(id)
  end
  local function refreshCore(core)
    truthy(core.requestSnapshot())
    return lastEvent
  end

  local GameCore = newCore()
  local initialRuntimeGeneration = GameCore.state.runtimeGeneration
  truthy(initialRuntimeGeneration)
  equal(GameCore.state.objectId, nil, "extension reload state must not retain object IDs")
  equal(GameCore.state.spawned, nil, "extension reload state must not retain old object bindings")
  truthy(refreshCore(GameCore))
  equal(lastEvent.status, "new")
  equal(#lastEvent.starterOptions, 3)
  truthy(GameCore.exportDiagnostics())
  equal(diagnosticsExportEvent.success, true)
  equal(diagnosticsExportEvent.path, "settings/perekup_diagnostics.json")
  equal(files["settings/perekup_diagnostics.json"].schema, 1)

  rejectSpawn = true
  equal(GameCore.startCareer(lastEvent.starterOptions[1].id), false)
  equal(lastEvent.status, "new")
  equal(lastSavedCareer(), nil)
  rejectSpawn = false
  truthy(GameCore.startCareer(lastEvent.starterOptions[1].id))
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, 500)
  local starterId = lastEvent.career.starterVehicleId
  local starterObjectId = lastEvent.career.vehicles[1].worldObjectId
  local starterName = worldObjects[starterObjectId].name
  local wrapperA = scenetree.findObject(starterName)
  local wrapperB = scenetree.findObject(starterName)
  truthy(wrapperA and wrapperB)
  equal(rawequal(wrapperA, wrapperB), false, "repeated BeamNG lookups may return distinct Lua wrappers")
  equal(World.getObjectId(starterId), starterObjectId,
    "a verified own vehicle must stay usable even when name lookup returns a fresh wrapper")
  local starterBindingProof = World.getBindingToken(starterId)
  truthy(starterBindingProof)
  local collisionSpawned, collisionId = World.spawn("runtime_collision_probe",
    { modelKey = "car_b", configKey = "foreign.probe" })
  truthy(collisionSpawned)
  local collisionForeign = placeForeignObject(collisionId, "car_b", "runtime.reused.id")
  equal(World.getObjectId("runtime_collision_probe"), nil,
    "a same-session numeric ID collision must invalidate the old named binding")
  equal(World.queueRepair("runtime_collision_probe", "R_runtime_collision", "settings/perekup_vehicle_states/probe_post.json"), false)
  equal(World.returnToGarage("runtime_collision_probe"), true,
    "returning an already-unbound record must not delete the replacement object")
  equal(collisionForeign.deleteCount, 0)
  equal(#collisionForeign.queuedCommands, 0)
  worldObjects[collisionId] = nil
  activeObjectId = starterObjectId
  equal(lastEvent.career.vehicles[1].inWorld, true)
  equal(GameCore.sellVehicle(starterId), false)
  equal(lastEvent.career.money, 500)

  truthy(GameCore.returnVehicle(starterId))
  equal(lastEvent.pendingStore.status, "saving")
  equal(lastEvent.career.vehicles[1].inWorld, true, "the object must remain until the physical file is verified")
  local storePending = Career.copy(lastSavedCareer().pendingStore)
  equal(storePending.objectId, nil, "pending career operations must never persist an engine object ID")
  seedStateFile(storePending.stateFile, storePending.configSnapshot, 77)
  local foreignAfterStoreRestart = placeForeignObject(starterObjectId, "car_b", "foreign.same-id")
  local legacyPendingStore = Career.copy(lastSavedCareer())
  legacyPendingStore.schema = 2
  legacyPendingStore.pendingStore.objectId = starterObjectId
  legacyPendingStore.vehicles[1].worldObjectId = starterObjectId
  files[Storage.SAVE_PATH] = legacyPendingStore
  local storeReloadGeneration = GameCore.state.runtimeGeneration
  package.loaded["perekup/world"] = nil
  World = require("perekup/world")
  GameCore = newCore()
  truthy(GameCore.state.runtimeGeneration > storeReloadGeneration,
    "a Lua extension reload must invalidate prior callback proofs")
  equal(GameCore.state.objectId, nil)
  equal(GameCore.state.spawned, nil)
  equal(lastEvent.pendingStore, nil, "a valid file must recover even when its save acknowledgement was lost")
  equal(lastEvent.career.vehicles[1].inWorld, false)
  equal(lastSavedCareer().schema, 3, "migration must remove legacy session object IDs")
  equal(lastSavedCareer().vehicles[1].worldObjectId, nil)
  equal(foreignAfterStoreRestart.deleteCount, 0, "a reused object ID must never delete a foreign car")
  equal(#foreignAfterStoreRestart.queuedCommands, 0, "a reused object ID must never receive a command")
  equal(worldObjects[starterObjectId], foreignAfterStoreRestart, "the colliding object must remain in the world")
  equal(lastSavedCareer().vehicles[1].configSnapshot.parts.engine, storePending.configSnapshot.parts.engine)
  equal(lastSavedCareer().vehicles[1].beamStateFile, storePending.stateFile)
  local balanceAfterStore = lastEvent.career.money
  equal(GameCore.onVehicleStateSaved(storePending.token, starterObjectId, "store", true, starterBindingProof), false)
  equal(lastEvent.career.money, balanceAfterStore, "a replayed completed store acknowledgement must not mutate the career")

  truthy(GameCore.listVehicle(starterId))
  local starterSalePrice = lastEvent.career.vehicles[1].askingPrice
  truthy(GameCore.sellVehicle(starterId))
  truthy(lastEvent.career.money > 500)

  local firstListing
  for _, offer in ipairs(lastEvent.career.listings) do
    local repairQuote = Economy.repairCost({ condition = offer.condition, marketValue = offer.marketValue })
    if offer.status == "available" and offer.price + repairQuote <= lastEvent.career.money
      and (not firstListing or offer.price < firstListing.price) then
      firstListing = offer
    end
  end
  truthy(firstListing, "expected an offer affordable with a repair reserve after the starter sale")
  truthy(GameCore.buyListing(firstListing.id))
  local boughtId = lastEvent.career.vehicles[2].id
  local afterPurchase = lastEvent.career.money
  equal(GameCore.buyListing(firstListing.id), false)
  equal(lastEvent.career.money, afterPurchase)

  truthy(GameCore.retrieveVehicle(boughtId))
  local oldObjectId = lastEvent.career.vehicles[2].worldObjectId
  local firstSpawnCount = spawnCount
  equal(lastEvent.career.vehicles[2].inWorld, true)
  equal(GameCore.retrieveVehicle(boughtId), false)
  equal(spawnCount, firstSpawnCount, "a repeated retrieve command must not create a duplicate object")
  equal(GameCore.listVehicle(boughtId), false)

  local repairQuote = lastEvent.career.vehicles[2].repairQuote
  local beforeRepair = lastEvent.career.money
  rejectGameSaveWrites = true
  equal(GameCore.repairVehicle(boughtId), false)
  equal(lastEvent.career.money, beforeRepair)
  rejectGameSaveWrites = false

  truthy(GameCore.repairVehicle(boughtId))
  local failedCheckpoint = Career.copy(lastSavedCareer().pendingRepair)
  local failedCheckpointProof = World.getBindingToken(boughtId)
  equal(failedCheckpoint.objectId, nil)
  equal(lastEvent.career.money, beforeRepair)
  equal(GameCore.repairVehicle(boughtId), false)
  equal(GameCore.advanceDay(), false)
  destroyObject(GameCore, oldObjectId)
  equal(lastSavedCareer().pendingRepair, nil, "a lost pre-checkpoint object can be cancelled without charging")
  equal(lastEvent.career.vehicles[2].repairUsed, false)
  equal(GameCore.onRepairResult(failedCheckpoint.token, oldObjectId, true, "saved", failedCheckpointProof), false)

  truthy(GameCore.retrieveVehicle(boughtId))
  oldObjectId = lastEvent.career.vehicles[2].worldObjectId
  truthy(GameCore.repairVehicle(boughtId))
  local repairPending = Career.copy(lastSavedCareer().pendingRepair)
  local repairBindingProof = World.getBindingToken(boughtId)
  equal(repairPending.objectId, nil)
  seedStateFile(repairPending.preStateFile, repairPending.configSnapshot, 91)
  truthy(GameCore.onVehicleStateSaved(repairPending.token, oldObjectId, "repair_checkpoint", true, repairBindingProof))
  equal(lastSavedCareer().pendingRepair.phase, "reset")
  equal(lastEvent.career.money, beforeRepair)

  destroyObject(GameCore, oldObjectId)
  truthy(lastSavedCareer().pendingRepair, "a possibly started reset survives loss of its old object ID")
  equal(lastEvent.career.money, beforeRepair)
  local staleRestoreSpawned, staleRestoreObjectId = World.spawn(
    "stale_restore_probe", { modelKey = "car_b", configKey = "foreign.probe" },
    repairPending.configSnapshot, repairPending.preStateFile)
  truthy(staleRestoreSpawned)
  local staleRestoreProof = World.getBindingToken("stale_restore_probe")
  local staleRestoreCommand = worldObjects[staleRestoreObjectId].queuedCommands[1]
  local staleRestoreToken = staleRestoreCommand
    and staleRestoreCommand:match('restoreState%([^,]+,%s*"([A-Za-z0-9_%-]+)"')
  truthy(staleRestoreProof)
  truthy(staleRestoreToken)
  destroyObject(GameCore, staleRestoreObjectId)
  local foreignAfterRepairRestart = placeForeignObject(oldObjectId, "car_b", "foreign.repair.same-id")
  local foreignAfterRestoreRestart = placeForeignObject(staleRestoreObjectId, "car_b", "foreign.restore.same-id")
  local legacyPendingRepair = Career.copy(lastSavedCareer())
  legacyPendingRepair.schema = 2
  legacyPendingRepair.pendingRepair.objectId = oldObjectId
  legacyPendingRepair.vehicles[2].objectId = oldObjectId
  files[Storage.SAVE_PATH] = legacyPendingRepair
  local repairReloadGeneration = GameCore.state.runtimeGeneration
  package.loaded["perekup/world"] = nil
  World = require("perekup/world")
  GameCore = newCore()
  truthy(GameCore.state.runtimeGeneration > repairReloadGeneration)
  truthy(lastSavedCareer().pendingRepair, "a reset with no post-file must remain pending after restart")
  equal(lastSavedCareer().pendingRepair.objectId, nil)
  equal(lastSavedCareer().vehicles[2].objectId, nil)
  equal(lastEvent.career.money, beforeRepair, "an unresolved reset must not debit on restart")
  equal(foreignAfterRepairRestart.deleteCount, 0, "a reused ID must never delete the foreign repair-collision car")
  equal(#foreignAfterRepairRestart.queuedCommands, 0, "a reused ID must never receive a repair command")
  equal(worldObjects[oldObjectId], foreignAfterRepairRestart)
  equal(GameCore.onRepairResult(repairPending.token, oldObjectId, true, "saved", repairBindingProof), false,
    "an old session callback must not be accepted for a reused ID")
  equal(GameCore.onVehicleStateRestored(staleRestoreToken, staleRestoreObjectId, false, staleRestoreProof), false,
    "a stale restore failure must not delete an object that reused the old ID")
  equal(foreignAfterRepairRestart.deleteCount, 0)
  equal(#foreignAfterRepairRestart.queuedCommands, 0)
  equal(foreignAfterRestoreRestart.deleteCount, 0)
  equal(#foreignAfterRestoreRestart.queuedCommands, 0)
  equal(worldObjects[staleRestoreObjectId], foreignAfterRestoreRestart)

  -- Reuse that numeric ID again for a new PEREKUP spawn, then deliver the old
  -- object's destruction hook. It must not discard the new live binding.
  worldObjects[staleRestoreObjectId] = nil
  nextObjectId = staleRestoreObjectId
  local reboundProbe, reboundProbeId = World.spawn(
    "stale_restore_probe", { modelKey = "car_b", configKey = "foreign.probe" },
    repairPending.configSnapshot)
  truthy(reboundProbe)
  equal(reboundProbeId, staleRestoreObjectId)
  World.onVehicleDestroyed(staleRestoreObjectId)
  equal(World.getObjectId("stale_restore_probe"), staleRestoreObjectId,
    "a stale destroy callback must not discard the new object that reused the ID")
  truthy(World.returnToGarage("stale_restore_probe", World.getBindingToken("stale_restore_probe")))

  local verifiedCheckpoint = Career.copy(files[repairPending.preStateFile])
  files[repairPending.preStateFile] = nil
  local beforeBlockedRetrieve = spawnCount
  equal(GameCore.retrieveVehicle(boughtId), false, "a missing repair checkpoint must not trigger an unverified free reset")
  equal(spawnCount, beforeBlockedRetrieve)
  files[repairPending.preStateFile] = verifiedCheckpoint
  truthy(GameCore.retrieveVehicle(boughtId))
  local newObjectId = lastEvent.career.vehicles[2].worldObjectId
  truthy(newObjectId ~= oldObjectId)
  truthy(World.getBindingToken(boughtId) ~= repairBindingProof,
    "a restarted GE session must issue a new binding proof even if BeamNG reuses the numeric ID")
  equal(worldObjects[newObjectId].config.parts.engine, repairPending.configSnapshot.parts.engine,
    "retrieval must rebuild the saved part configuration before loading physical state")
  local restoreCommand = worldObjects[newObjectId].queuedCommands[1]
  local restoreToken = restoreCommand and restoreCommand:match('restoreState%([^,]+,%s*"([A-Za-z0-9_%-]+)"')
  local newBindingProof = World.getBindingToken(boughtId)
  truthy(restoreToken, "retrieval must queue the verified physical checkpoint restore")
  truthy(newBindingProof)
  truthy(GameCore.onVehicleStateRestored(restoreToken, newObjectId, true, newBindingProof))
  equal(lastSavedCareer().pendingRepair.objectId, nil, "the rebound object ID stays runtime-only")
  truthy(worldObjects[newObjectId].queuedCommands[2]:find("requestRepair", 1, true))
  local pendingAfterRebind = Career.copy(lastSavedCareer().pendingRepair)
  seedStateFile(pendingAfterRebind.postStateFile, pendingAfterRebind.configSnapshot, 101)

  GameCore = newCore()
  equal(lastEvent.pendingRepair, nil, "a verified post-reset file must complete a repair after a lost acknowledgement")
  equal(lastEvent.career.money, beforeRepair - repairQuote)
  equal(lastEvent.career.vehicles[2].condition, 100)
  equal(lastEvent.career.vehicles[2].repairUsed, true)
  equal(GameCore.onRepairResult(repairPending.token, newObjectId, true, "saved", newBindingProof), false)
  equal(lastEvent.career.money, beforeRepair - repairQuote, "duplicate repair callbacks must not debit twice")

  equal(lastEvent.career.vehicles[2].inWorld, false,
    "a GE extension reload must drop runtime ownership without touching the live object")
  truthy(worldObjects[newObjectId], "the unbound world object is left for manual cleanup")
  destroyObject(GameCore, newObjectId)
  truthy(GameCore.retrieveVehicle(boughtId))
  newObjectId = lastEvent.career.vehicles[2].worldObjectId
  restoreCommand = worldObjects[newObjectId].queuedCommands[1]
  restoreToken = restoreCommand and restoreCommand:match('restoreState%([^,]+,%s*"([A-Za-z0-9_%-]+)"')
  newBindingProof = World.getBindingToken(boughtId)
  truthy(restoreToken)
  truthy(GameCore.onVehicleStateRestored(restoreToken, newObjectId, true, newBindingProof))

  local storedBeforeFailure = lastSavedCareer().vehicles[2].beamStateFile
  truthy(GameCore.returnVehicle(boughtId))
  local missingStore = Career.copy(lastSavedCareer().pendingStore)
  local missingStoreObjectId = World.getObjectId(boughtId)
  destroyObject(GameCore, missingStoreObjectId)
  equal(lastSavedCareer().pendingStore, nil, "a missing object without a verified new file cancels only the store operation")
  equal(lastSavedCareer().vehicles[2].beamStateFile, storedBeforeFailure, "the previous physical save must remain available")
  equal(lastEvent.career.money, beforeRepair - repairQuote)

  local validStoredFile = Career.copy(files[storedBeforeFailure])
  files[storedBeforeFailure].parts = { incompatible = true }
  local beforeRejectedSpawn = spawnCount
  equal(GameCore.retrieveVehicle(boughtId), false)
  equal(spawnCount, beforeRejectedSpawn, "a mismatched physical save must fail before spawning")
  files[storedBeforeFailure] = validStoredFile
  truthy(GameCore.retrieveVehicle(boughtId))
  newObjectId = lastEvent.career.vehicles[2].worldObjectId
  restoreCommand = worldObjects[newObjectId].queuedCommands[1]
  restoreToken = restoreCommand and restoreCommand:match('restoreState%([^,]+,%s*"([A-Za-z0-9_%-]+)"')
  newBindingProof = World.getBindingToken(boughtId)
  truthy(restoreToken)
  truthy(GameCore.onVehicleStateRestored(restoreToken, newObjectId, true, newBindingProof))
  truthy(GameCore.returnVehicle(boughtId))
  local finalStore = Career.copy(lastSavedCareer().pendingStore)
  local finalStoreProof = World.getBindingToken(boughtId)
  equal(finalStore.objectId, nil)
  seedStateFile(finalStore.stateFile, finalStore.configSnapshot, 111)
  truthy(GameCore.onVehicleStateSaved(finalStore.token, newObjectId, "store", true, finalStoreProof))
  equal(lastEvent.career.vehicles[2].inWorld, false)
  equal(lastSavedCareer().vehicles[2].beamStateFile, finalStore.stateFile)

  truthy(GameCore.listVehicle(boughtId))
  local salePrice = lastEvent.career.vehicles[2].askingPrice
  truthy(GameCore.sellVehicle(boughtId))
  equal(lastEvent.career.money, beforeRepair - repairQuote + salePrice)
  equal(lastEvent.career.vehicles[2].status, "sold")
  truthy(lastSavedCareer())

  GameCore = newCore()
  truthy(refreshCore(GameCore))
  equal(lastEvent.status, "active")
  equal(lastEvent.career.money, lastSavedCareer().money)
  equal(lastEvent.career.history[#lastEvent.career.history].kind, "sale")
  truthy(starterSalePrice > 0)
end)

print(string.format("%d Lua tests passed", testsRun))
