local M = {}

local SAFE_PATH = "^settings/perekup_vehicle_states/[A-Za-z0-9_%-]+%.json$"
local pendingRepair
local completedRepair
local completedSaves = {}
local completedRestores = {}
local repairRetryElapsed = 0

local function diagnostic(event, result, api)
  local logger = rawget(_G, "log")
  if type(logger) ~= "function" then return end
  local level = result == "failed" and "E" or (result == "unavailable" and "W" or "I")
  local suffix = type(api) == "string" and api:match("^[A-Za-z0-9_.:]+$") and " api=" .. api or ""
  pcall(logger, level, "PEREKUP", event .. " result=" .. result .. suffix)
end

local function currentVehicleId()
  if obj == nil then return nil end
  local getter = obj.getID or obj.getId
  if type(getter) ~= "function" then return nil end
  local ok, value = pcall(getter, obj)
  value = ok and tonumber(value) or nil
  if not value or value ~= math.floor(value) or value < 0 then return nil end
  return value
end

local function safeToken(token)
  return type(token) == "string" and #token > 0 and #token <= 64
    and token:match("^[A-Za-z0-9_%-]+$") ~= nil
end

local function safePath(path)
  return type(path) == "string" and #path <= 160 and path:match(SAFE_PATH) ~= nil
end

local function countEntries(value)
  if type(value) ~= "table" then return -1 end
  local count = 0
  for _ in pairs(value) do count = count + 1 end
  return count
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

local function readValidBeamstate(path)
  if not safePath(path) or type(jsonReadFile) ~= "function" or type(v) ~= "table"
    or type(v.data) ~= "table" or type(v.data.nodes) ~= "table" or type(v.data.beams) ~= "table"
    or type(v.userPartConfig) ~= "table" or type(v.userVars) ~= "table" then
    return nil
  end
  local ok, saved = pcall(jsonReadFile, path)
  if not ok or type(saved) ~= "table" then return nil end
  local nodeCount = countEntries(v.data.nodes)
  local beamCount = countEntries(v.data.beams)
  if saved.format ~= "v2" or saved.vehicleDirectory ~= v.data.vehicleDirectory
    or saved.model ~= v.data.model or saved.nodeCount ~= nodeCount or saved.beamCount ~= beamCount
    or type(saved.nodes) ~= "table" or countEntries(saved.nodes) ~= nodeCount
    or type(saved.beams) ~= "table" or countEntries(saved.beams) ~= beamCount
    or type(saved.hydros) ~= "table"
    or not sameData(saved.parts, v.userPartConfig) or not sameData(saved.vars, v.userVars) then
    return nil
  end
  return saved
end

local function reportGameEngine(functionName, token, objectId, kind, succeeded, resultCode, bindingProof)
  if obj == nil or type(obj.queueGameEngineLua) ~= "function" or not safeToken(bindingProof) then return false end
  local command
  if functionName == "onVehicleStateSaved" then
    command = string.format("extensions.perekup_core.%s(%q, %d, %q, %s, %q)",
      functionName, token, objectId, kind, tostring(succeeded), bindingProof)
  elseif functionName == "onRepairResult" then
    command = string.format("extensions.perekup_core.%s(%q, %d, %s, %q, %q)",
      functionName, token, objectId, tostring(succeeded), resultCode, bindingProof)
  else
    command = string.format("extensions.perekup_core.%s(%q, %d, %s, %q)",
      functionName, token, objectId, tostring(succeeded), bindingProof)
  end
  local ok, result = pcall(obj.queueGameEngineLua, obj, command)
  if not ok or result == false then diagnostic("vehicle.callback", "failed", "obj.queueGameEngineLua") end
  return ok and result ~= false
end

local function requestSave(path, token, kind, bindingProof)
  local objectId = currentVehicleId()
  local key = tostring(token) .. ":" .. tostring(kind) .. ":" .. tostring(path) .. ":" .. tostring(objectId) .. ":" .. tostring(bindingProof)
  if completedSaves[key] then
    reportGameEngine("onVehicleStateSaved", token, objectId, kind, true, nil, bindingProof)
    return true
  end
  if not safeToken(token) or not safeToken(bindingProof) or not safePath(path) or objectId == nil
    or (kind ~= "store" and kind ~= "repair_checkpoint")
    or type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then
    if safeToken(token) and objectId then
      reportGameEngine("onVehicleStateSaved", token, objectId, kind, false, nil, bindingProof)
    end
    diagnostic("vehicle.state.save", "unavailable", "beamstate.save")
    return false
  end

  local savedOk, saveResult = pcall(beamstate.save, path)
  local verified = savedOk and saveResult ~= false and readValidBeamstate(path) ~= nil
  if verified then completedSaves[key] = true end
  reportGameEngine("onVehicleStateSaved", token, objectId, kind, verified, nil, bindingProof)
  diagnostic("vehicle.state.save", verified and "ok" or "failed", "beamstate.save")
  return verified
end

function M.saveState(path, token, kind, bindingProof)
  return requestSave(path, token, kind, bindingProof)
end

function M.restoreState(path, token, bindingProof)
  local objectId = currentVehicleId()
  local key = tostring(token) .. ":" .. tostring(path) .. ":" .. tostring(objectId) .. ":" .. tostring(bindingProof)
  if completedRestores[key] then
    reportGameEngine("onVehicleStateRestored", token, objectId, nil, true, nil, bindingProof)
    return true
  end
  if not safeToken(token) or not safeToken(bindingProof) or not safePath(path) or objectId == nil
    or type(beamstate) ~= "table" or type(beamstate.load) ~= "function"
    or not readValidBeamstate(path) then
    if safeToken(token) and objectId then
      reportGameEngine("onVehicleStateRestored", token, objectId, nil, false, nil, bindingProof)
    end
    diagnostic("vehicle.state.restore", "unavailable", "beamstate.load")
    return false
  end
  local loadedOk, loadResult = pcall(beamstate.load, path)
  local loaded = loadedOk and loadResult ~= false
  if loaded then completedRestores[key] = true end
  reportGameEngine("onVehicleStateRestored", token, objectId, nil, loaded, nil, bindingProof)
  diagnostic("vehicle.state.restore", loaded and "ok" or "failed", "beamstate.load")
  return loaded
end

local function saveCompletedRepair()
  if not pendingRepair or not pendingRepair.resetDone then return false end
  if type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then
    diagnostic("repair.checkpoint", "unavailable", "beamstate.save")
    return false
  end
  local ok, saveResult = pcall(beamstate.save, pendingRepair.postStateFile)
  if not ok or saveResult == false or not readValidBeamstate(pendingRepair.postStateFile) then
    diagnostic("repair.checkpoint", "failed", "beamstate.save")
    return false
  end
  local finished = pendingRepair
  pendingRepair = nil
  completedRepair = finished
  repairRetryElapsed = 0
  reportGameEngine("onRepairResult", finished.token, finished.objectId, nil, true, "saved", finished.bindingProof)
  diagnostic("repair.checkpoint", "ok", "beamstate.save")
  return true
end

function M.requestRepair(token, postStateFile, bindingProof)
  local objectId = currentVehicleId()
  if not safeToken(token) or not safeToken(bindingProof) or not safePath(postStateFile) or objectId == nil then return false end
  if completedRepair and completedRepair.token == token and completedRepair.objectId == objectId
    and completedRepair.postStateFile == postStateFile and completedRepair.bindingProof == bindingProof then
    reportGameEngine("onRepairResult", token, objectId, nil, true, "saved", bindingProof)
    return true
  end
  if pendingRepair then
    if pendingRepair.token ~= token or pendingRepair.objectId ~= objectId
      or pendingRepair.postStateFile ~= postStateFile or pendingRepair.bindingProof ~= bindingProof then
      return false
    end
    if pendingRepair.resetDone then saveCompletedRepair() end
    return true
  end
  if RESET_PHYSICS == nil or type(obj.requestReset) ~= "function"
    or type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then
    reportGameEngine("onRepairResult", token, objectId, nil, false, "rejected", bindingProof)
    diagnostic("repair.reset", "unavailable", "obj.requestReset")
    return false
  end

  pendingRepair = {
    token = token,
    objectId = objectId,
    bindingProof = bindingProof,
    postStateFile = postStateFile,
    resetDone = false
  }
  repairRetryElapsed = 0
  local ok, result = pcall(obj.requestReset, obj, RESET_PHYSICS)
  if not ok or result == false then
    pendingRepair = nil
    reportGameEngine("onRepairResult", token, objectId, nil, false, "rejected", bindingProof)
    diagnostic("repair.reset", "failed", "obj.requestReset")
    return false
  end
  if type(obj.resetBrokenFlexMesh) == "function" then
    pcall(obj.resetBrokenFlexMesh, obj)
  end
  diagnostic("repair.reset", "started", "obj.requestReset")
  return true
end

function M.onReset()
  if not pendingRepair or pendingRepair.objectId ~= currentVehicleId() then return end
  pendingRepair.resetDone = true
  repairRetryElapsed = 0
  diagnostic("repair.reset", "confirmed", "onReset")
end

function M.updateGFX(dt)
  if not pendingRepair or not pendingRepair.resetDone then return end
  repairRetryElapsed = repairRetryElapsed + (tonumber(dt) or 0)
  if repairRetryElapsed >= 0.1 then
    saveCompletedRepair()
    if pendingRepair then repairRetryElapsed = 0 end
  end
end

diagnostic("vehicle.state.extension", "loaded")
return M
