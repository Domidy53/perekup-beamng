local Listings = require("perekup/listings")

local M = {}

function M.advanceDay(state, configs)
  if state.day >= 10000000 then
    return false, "Достигнут предел игрового календаря."
  end
  state.day = state.day + 1
  state.listings = Listings.create(configs, state.day, state.vehicles)
  return true
end

return M
