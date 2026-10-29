local Economy = require("perekup/economy")

local M = {}

function M.perform(state, vehicle)
  if not vehicle or vehicle.status ~= "owned" then
    return false, "Автомобиль сейчас нельзя ремонтировать."
  end
  if vehicle.repairUsed or vehicle.condition >= 100 then
    return false, "Для этого автомобиля ремонт уже выполнен."
  end
  local cost = Economy.repairCost(vehicle)
  if state.money < cost then
    return false, "На ремонт нужно $" .. tostring(cost) .. "."
  end

  state.money = state.money - cost
  vehicle.condition = Economy.repairCondition(vehicle.condition)
  vehicle.repairCost = vehicle.repairCost + cost
  vehicle.repairUsed = true
  return true
end

return M
