---@class OrgCompletionColumns:OrgCompletionSource
---@field private directive_pattern vim.regex
local OrgCompletionColumns = {}
OrgCompletionColumns.__index = OrgCompletionColumns

local COLUMN_KEYWORDS = {
  '%ITEM',
  '%TODO',
  '%PRIORITY',
  '%TAGS',
  '%CATEGORY',
  '%SCHEDULED',
  '%DEADLINE',
  '%CLOCKSUM',
  '%CLOCKSUM_T',
  '%AGE',
}

local SUMMARY_TYPES = {
  '+',
  ':',
  '$',
  'min',
  'max',
  'mean',
  'X',
  'X/',
  '@mean',
  'est+',
  '+;%.2f',
}

function OrgCompletionColumns:new()
  return setmetatable({
    directive_pattern = vim.regex([[\c^\s*\(\#+columns:\|:columns:\)\s]]),
  }, OrgCompletionColumns)
end

function OrgCompletionColumns:get_name()
  return 'columns'
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionColumns:get_start(context)
  if not self.directive_pattern:match_str(context.line) then
    return nil
  end

  -- The spec is a list of whitespace separated tokens; complete the last one.
  local prefix = context.line:match('^(.-)%S*$')
  return #prefix
end

---@param context OrgCompletionContext
---@return string[]
function OrgCompletionColumns:get_results(context)
  local base = context.base or ''

  -- When a token is opened with `{`, offer the summary forms for it, e.g.
  -- `%Effort{` -> `%Effort{+}`.
  local name = base:match('^([^{]*){$')
  if name then
    local results = {}
    for _, summary_type in ipairs(SUMMARY_TYPES) do
      table.insert(results, name .. '{' .. summary_type .. '}')
    end
    return results
  end

  return COLUMN_KEYWORDS
end

return OrgCompletionColumns
