local M = {}

local EVENTS_PATH = "settings/perekup_diagnostics.json"
local MAX_EVENTS = 100
local events = {}

local function safeCode(value)
  return type(value) == "string" and #value > 0 and #value <= 64
    and value:match("^[A-Za-z0-9_.%-]+$") ~= nil
end

local function timestamp()
  local ok, value = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ")
  return ok and type(value) == "string" and value or "unknown"
end

function M.record(event, result)
  if not safeCode(event) or (result ~= nil and not safeCode(result)) then return false end
  local entry = { at = timestamp(), event = event, result = result or "ok" }
  events[#events + 1] = entry
  if #events > MAX_EVENTS then table.remove(events, 1) end

  local logger = rawget(_G, "log")
  if type(logger) == "function" then
    local level = "I"
    if result == "failed" then level = "E"
    elseif result == "unavailable" or result == "unverified" then level = "W" end
    pcall(logger, level, "PEREKUP", event .. " result=" .. entry.result)
  end
  return true
end

function M.snapshot(context)
  local copiedEvents = {}
  for index, entry in ipairs(events) do
    copiedEvents[index] = { at = entry.at, event = entry.event, result = entry.result }
  end
  return {
    schema = 1,
    createdAt = timestamp(),
    career = context or {},
    events = copiedEvents
  }
end

function M.export(context)
  local fs = rawget(_G, "FS")
  local exists = false
  if fs and type(fs.directoryExists) == "function" then
    local ok, value = pcall(function() return fs:directoryExists("settings") end)
    exists = ok and value == true
  end
  if not exists then
    if not fs or type(fs.directoryCreate) ~= "function" then
      M.record("diagnostics.export", "unavailable")
      return false, "Папка настроек игры недоступна."
    end
    local ok, value = pcall(function() return fs:directoryCreate("settings", true) end)
    if not ok or value == false then
      M.record("diagnostics.export", "failed")
      return false, "Не удалось подготовить папку настроек игры."
    end
  end

  local writer = rawget(_G, "jsonWriteFile")
  if type(writer) ~= "function" then
    M.record("diagnostics.export", "unavailable")
    return false, "JSON-функция игры недоступна."
  end
  local ok, result = pcall(writer, EVENTS_PATH, M.snapshot(context), true)
  if not ok or result == false then
    M.record("diagnostics.export", "failed")
    return false, "Игра не подтвердила запись диагностического файла."
  end
  if fs and type(fs.fileExists) == "function" then
    local existsOk, written = pcall(function() return fs:fileExists(EVENTS_PATH) end)
    if not existsOk or written ~= true then
      M.record("diagnostics.export", "failed")
      return false, "Диагностический файл не найден после записи."
    end
  end
  M.record("diagnostics.export", "ok")
  return true, EVENTS_PATH
end

M.EVENTS_PATH = EVENTS_PATH
return M
