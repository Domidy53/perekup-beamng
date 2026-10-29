local M = {}

local SAFE_PATH = "^settings/perekup_vehicle_states/[A-Za-z0-9_%-]+%.json$"
local pendingRepair
local completedRepair
local completedSaves = {}
local completedRestores = {}
local repairRetryElapsed = 0

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

local function reportGameEngine(functionName, token, objectId, kind, succeeded, resultCode)
  if obj == nil or type(obj.queueGameEngineLua) ~= "function" then return false end
  local command
  if type(kind) == "string" then
    command = string.format("extensions.perekup_core.%s(%q, %d, %q, %s)",
      functionName, token, objectId, kind, tostring(succeeded))
  elseif resultCode then
    command = string.format("extensions.perekup_core.%s(%q, %d, %s, %q)",
      functionName, token, objectId, tostring(succeeded), resultCode)
  else
    command = string.format("extensions.perekup_core.%s(%q, %d, %s)",
      functionName, token, objectId, tostring(succeeded))
  end
  local ok, result = pcall(obj.queueGameEngineLua, obj, command)
  return ok and result ~= false
end

local function requestSave(path, token, kind)
  local objectId = currentVehicleId()
  local key = tostring(token) .. ":" .. tostring(kind) .. ":" .. tostring(path) .. ":" .. tostring(objectId)
  if completedSaves[key] then
    reportGameEngine("onVehicleStateSaved", token, objectId, kind, true)
    return true
  end
  if not safeToken(token) or not safePath(path) or objectId == nil
    or (kind ~= "store" and kind ~= "repair_checkpoint")
    or type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then
    if safeToken(token) and objectId then
      reportGameEngine("onVehicleStateSaved", token, objectId, kind, false)
    end
    return false
  end

  local savedOk, saveResult = pcall(beamstate.save, path)
  local verified = savedOk and saveResult ~= false and readValidBeamstate(path) ~= nil
  if verified then completedSaves[key] = true end
  reportGameEngine("onVehicleStateSaved", token, objectId, kind, verified)
  return verified
end

function M.saveState(path, token, kind)
  return requestSave(path, token, kind)
end

function M.restoreState(path, token)
  local objectId = currentVehicleId()
  local key = tostring(token) .. ":" .. tostring(path) .. ":" .. tostring(objectId)
  if completedRestores[key] then
    reportGameEngine("onVehicleStateRestored", token, objectId, nil, true)
    return true
  end
  if not safeToken(token) or not safePath(path) or objectId == nil
    or type(beamstate) ~= "table" or type(beamstate.load) ~= "function"
    or not readValidBeamstate(path) then
    if safeToken(token) and objectId then
      reportGameEngine("onVehicleStateRestored", token, objectId, nil, false)
    end
    return false
  end
  local loadedOk, loadResult = pcall(beamstate.load, path)
  local loaded = loadedOk and loadResult ~= false
  if loaded then completedRestores[key] = true end
  reportGameEngine("onVehicleStateRestored", token, objectId, nil, loaded)
  return loaded
end

local function saveCompletedRepair()
  if not pendingRepair or not pendingRepair.resetDone then return false end
  if type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then return false end
  local ok, saveResult = pcall(beamstate.save, pendingRepair.postStateFile)
  if not ok or saveResult == false or not readValidBeamstate(pendingRepair.postStateFile) then return false end
  local finished = pendingRepair
  pendingRepair = nil
  completedRepair = finished
  repairRetryElapsed = 0
  reportGameEngine("onRepairResult", finished.token, finished.objectId, nil, true, "saved")
  return true
end

function M.requestRepair(token, postStateFile)
  local objectId = currentVehicleId()
  if not safeToken(token) or not safePath(postStateFile) or objectId == nil then return false end
  if completedRepair and completedRepair.token == token and completedRepair.objectId == objectId
    and completedRepair.postStateFile == postStateFile then
    reportGameEngine("onRepairResult", token, objectId, nil, true, "saved")
    return true
  end
  if pendingRepair then
    if pendingRepair.token ~= token or pendingRepair.objectId ~= objectId
      or pendingRepair.postStateFile ~= postStateFile then
      return false
    end
    if pendingRepair.resetDone then saveCompletedRepair() end
    return true
  end
  if RESET_PHYSICS == nil or type(obj.requestReset) ~= "function"
    or type(beamstate) ~= "table" or type(beamstate.save) ~= "function" then
    reportGameEngine("onRepairResult", token, objectId, nil, false, "rejected")
    return false
  end

  pendingRepair = {
    token = token,
    objectId = objectId,
    postStateFile = postStateFile,
    resetDone = false
  }
  repairRetryElapsed = 0
  local ok, result = pcall(obj.requestReset, obj, RESET_PHYSICS)
  if not ok or result == false then
    pendingRepair = nil
    reportGameEngine("onRepairResult", token, objectId, nil, false, "rejected")
    return false
  end
  if type(obj.resetBrokenFlexMesh) == "function" then
    pcall(obj.resetBrokenFlexMesh, obj)
  end
  return true
end

function M.onReset()
  if not pendingRepair or pendingRepair.objectId ~= currentVehicleId() then return end
  pendingRepair.resetDone = true
  repairRetryElapsed = 0
end

function M.updateGFX(dt)
  if not pendingRepair or not pendingRepair.resetDone then return end
  repairRetryElapsed = repairRetryElapsed + (tonumber(dt) or 0)
  if repairRetryElapsed >= 0.1 then
    saveCompletedRepair()
    if pendingRepair then repairRetryElapsed = 0 end
  end
end

return M
