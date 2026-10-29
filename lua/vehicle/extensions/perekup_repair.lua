local M = {}
local pendingToken
local pendingVehicleId
local completedToken
local completedVehicleId

local function vehicleId()
  if obj == nil then
    return nil
  end
  local getter = obj.getID or obj.getId
  if type(getter) ~= "function" then
    return nil
  end
  local ok, value = pcall(getter, obj)
  value = ok and tonumber(value) or nil
  if not value or value ~= math.floor(value) or value < 0 then
    return nil
  end
  return value
end

local function report(token, id, succeeded)
  if obj == nil or type(obj.queueGameEngineLua) ~= "function" then
    return false
  end
  local command = string.format("extensions.perekup_core.onRepairResult('%s', %d, %s)", token, id, tostring(succeeded))
  local ok, result = pcall(obj.queueGameEngineLua, obj, command)
  return ok and result ~= false
end

function M.requestRepair(token)
  if type(token) ~= "string" or not token:match("^[A-Za-z0-9_-]+$") or #token > 64 then
    return false
  end
  if pendingToken then
    return pendingToken == token and pendingVehicleId == vehicleId()
  end
  local id = vehicleId()
  if completedToken == token and completedVehicleId == id then
    return report(token, id, true)
  end
  if id == nil or RESET_PHYSICS == nil or type(obj.queueGameEngineLua) ~= "function"
    or type(obj.requestReset) ~= "function" then
    if id then report(token, id, false) end
    return false
  end

  pendingToken = token
  pendingVehicleId = id
  local ok, result = pcall(obj.requestReset, obj, RESET_PHYSICS)
  if not ok or result == false then
    pendingToken, pendingVehicleId = nil, nil
    report(token, id, false)
    return false
  end
  if type(obj.resetBrokenFlexMesh) == "function" then
    pcall(obj.resetBrokenFlexMesh, obj)
  end
  return true
end

function M.onReset()
  if not pendingToken or not pendingVehicleId then
    return
  end
  local token, id = pendingToken, pendingVehicleId
  pendingToken, pendingVehicleId = nil, nil
  completedToken, completedVehicleId = token, id
  report(token, id, true)
end

return M
