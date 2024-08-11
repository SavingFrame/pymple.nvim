local M = {}

local utils = require("pymple.utils")
local jobs = require("pymple.jobs")
local Path = require("plenary.path")
local print_err = require("pymple.utils").print_err

-- classes, functions, and variables
local class_pattern = [['^class\s+%s\b']]
local function_pattern = [['^def\s+%s\b']]
local variable_pattern = [['^%s\s*=']]

local IMPORTABLE_SYMBOLS_PATTERNS = {
  class_pattern,
  function_pattern,
  variable_pattern,
}

---@param args table
---@param symbol string
---@param regexes string[]
---@return table
local function add_symbol_regexes(args, symbol, regexes)
  regexes = regexes or IMPORTABLE_SYMBOLS_PATTERNS
  for _, pattern in ipairs(regexes) do
    table.insert(args, "-e")
    table.insert(args, string.format(pattern, symbol))
  end
  return args
end

M.add_symbol_regexes = add_symbol_regexes

---@param symbol string: the symbol for which to resolve an import
---@param current_file_path string: the path to the current file
---@return string[] | nil: list of candidates
function M.resolve_python_import(symbol, current_file_path)
  if not utils.is_python_file(vim.fn.expand("%")) then
    print_err("Not a python file")
    return
  end
  local cwd = vim.fn.getcwd()
  local venv = utils.get_virtual_environment(cwd)
  local site_packages_location = Path:new(utils.get_site_packages_location())
    :make_relative(cwd)

  local local_args = { "-fCH", "-t", "python", "-I", current_file_path }
  local_args =
    add_symbol_regexes(local_args, symbol, IMPORTABLE_SYMBOLS_PATTERNS)
  table.insert(local_args, ".")
  local candidate_paths = jobs.find_import_candidates_in_workspace(local_args)

  -- FIXME:
  -- if venv and site_packages_location then
  --   local venv_args = { "-f", "-t", "python", "-C", "-G" }
  --   venv_args = add_symbol_regexes(venv_args, symbol)
  --   table.insert(venv_args, site_packages_location)
  --   local venv_candidates =
  --     jobs.find_import_candidates_in_venv(venv_args, site_packages_location)
  --   for _, candidate in ipairs(venv_candidates) do
  --     table.insert(candidate_paths, candidate)
  --   end
  -- end

  local candidates = {}

  for _, path in ipairs(candidate_paths) do
    local _path = string.gsub(path, "^%./", "")
    local import_path = utils.to_import_path(_path)
    table.insert(candidates, import_path)
  end
  -- sort imports by length
  table.sort(candidates, function(a, b)
    return #a < #b
  end)

  return candidates
end

return M
