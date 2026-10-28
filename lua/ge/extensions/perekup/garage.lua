local M = {}

function M.findById(vehicles, vehicleId)
  for _, vehicle in ipairs(vehicles or {}) do
    if vehicle.id == vehicleId then
      return vehicle
    end
  end
  return nil
end

function M.add(vehicles, vehicle)
  if M.findById(vehicles, vehicle.id) then
    return false
  end
  vehicles[#vehicles + 1] = vehicle
  return true
end

function M.activeCount(vehicles)
  local count = 0
  for _, vehicle in ipairs(vehicles or {}) do
    if vehicle.status ~= "sold" then
      count = count + 1
    end
  end
  return count
end

return M
