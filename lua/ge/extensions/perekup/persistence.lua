local Career = require("perekup/career")

local M = {}
local SAVE_PATH = "settings/perekup_career.json"
local BACKUP_PATH = "settings/perekup_career.json.bak"
local MAX_SAVE_BYTES = 1024 * 1024

local function hasFsMethod(name)
  if FS == nil then
    return false
  end
  local ok, method = pcall(function()
    return FS[name]
  end)
  return ok and type(method) == "function"
end

local function defaultAdapter()
  return {
    prepare = function()
      if not hasFsMethod("fileExists") or not hasFsMethod("directoryCreate") then
        return false
      end
      local ok, exists = false, false
      if hasFsMethod("directoryExists") then
        ok, exists = pcall(function()
          return FS:directoryExists("settings")
        end)
      end
      if ok and exists then
        return true
      end
      local createOk, created = pcall(function()
        return FS:directoryCreate("settings", true)
      end)
      return createOk and created ~= false
    end,
    exists = function(path)
      if not hasFsMethod("fileExists") then
        return nil, "FS:fileExists is unavailable"
      end
      local ok, result = pcall(function()
        return FS:fileExists(path)
      end)
      if not ok then
        return nil, "Could not inspect the career save"
      end
      return result == true
    end,
    read = function(path)
      if hasFsMethod("fileSize") then
        local sizeOk, size = pcall(function()
          return FS:fileSize(path)
        end)
        if sizeOk and type(size) == "number" and size > MAX_SAVE_BYTES then
          return nil, "Career save exceeds the size limit"
        end
      end
      if type(jsonReadFile) ~= "function" then
        return nil, "jsonReadFile is unavailable"
      end
      local ok, data = pcall(jsonReadFile, path)
      if not ok then
        return nil, "Could not read the career save"
      end
      return data
    end,
    write = function(path, state)
      if type(jsonWriteFile) ~= "function" then
        return false
      end
      local ok, result = pcall(jsonWriteFile, path, state)
      return ok and result ~= false
    end
  }
end

local function deepEqual(left, right)
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return left == right
  end
  for key, value in pairs(left) do
    if not deepEqual(value, right[key]) then
      return false
    end
  end
  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end
  return true
end

function M.new(adapter)
  adapter = adapter or defaultAdapter()
  local store = {}

  local function writeAndVerify(path, state)
    local ok, result = pcall(adapter.write, path, state)
    if not ok or result == false then
      return false
    end
    local readOk, readback = pcall(adapter.read, path)
    return readOk and Career.isValidState(readback) and deepEqual(state, readback)
  end

  function store.load()
    if type(adapter.exists) ~= "function" or type(adapter.read) ~= "function" then
      return nil, "Сохранения недоступны: файловый API игры не найден."
    end
    local primaryOk, primaryExists, primaryError = pcall(adapter.exists, SAVE_PATH)
    local backupOk, backupExists, backupError = pcall(adapter.exists, BACKUP_PATH)
    if not primaryOk or not backupOk or primaryExists == nil or backupExists == nil then
      return nil, primaryError or backupError or "Сохранения недоступны: файловый API игры не найден."
    end
    if not primaryExists and not backupExists then
      return nil, nil
    end

    if primaryExists then
      local readOk, state = pcall(adapter.read, SAVE_PATH)
      if readOk and Career.isValidState(state) then
        return state, nil
      end
    end
    if backupExists then
      local readOk, state = pcall(adapter.read, BACKUP_PATH)
      if readOk and Career.isValidState(state) then
        return state, "Резервная копия карьеры восстановлена. Последние действия могли не сохраниться."
      end
    end
    return nil, "Файл карьеры повреждён, а проверенная резервная копия недоступна. Новая карьера заблокирована, чтобы не затереть сохранение."
  end

  function store.save(candidate, current)
    if not Career.isValidState(candidate) or type(adapter.write) ~= "function" or type(adapter.read) ~= "function" then
      return false
    end
    if type(adapter.prepare) == "function" then
      local ok, ready = pcall(adapter.prepare)
      if not ok or ready == false then
        return false
      end
    end
    if current and not writeAndVerify(BACKUP_PATH, current) then
      return false
    end
    return writeAndVerify(SAVE_PATH, candidate)
  end

  return store
end

M.SAVE_PATH = SAVE_PATH
M.BACKUP_PATH = BACKUP_PATH
return M
