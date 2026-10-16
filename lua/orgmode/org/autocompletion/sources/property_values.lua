local config = require('orgmode.config')

---@class OrgCompletionPropertyValues:OrgCompletionSource
---@field private completion OrgCompletion
---@field private value_sources table<string, fun(this: OrgCompletionPropertyValues): string[]>
local OrgCompletionPropertyValues = {}
OrgCompletionPropertyValues.__index = OrgCompletionPropertyValues

function OrgCompletionPropertyValues:new(opts)
  return setmetatable({
    completion = opts.completion,
    value_sources = {
      CATEGORY = function(this)
        return this.completion.files:get_categories()
      end,
      REPEAT_TO_STATE = function()
        return config:get_todo_keywords():all_values()
      end,
    },
  }, OrgCompletionPropertyValues)
end

function OrgCompletionPropertyValues:get_name()
  return 'property_values'
end

---@private
---@param line string
---@return fun(this: OrgCompletionPropertyValues): string[] | nil
function OrgCompletionPropertyValues:_value_source(line)
  local name = line:match('^%s*#%+([%w_]+):%s') or line:match('^%s*:([%w_]+):%s')
  if not name then
    return nil
  end

  return self.value_sources[name:upper()]
end

---@param context OrgCompletionContext
---@return number | nil
function OrgCompletionPropertyValues:get_start(context)
  if not self:_value_source(context.line) then
    return nil
  end

  -- The value is everything after the property/directive name, so complete
  -- the whole tail (values can contain spaces, e.g. categories).
  local prefix = context.line:match('^(%s*[%S]+:%s*)')
  return prefix and #prefix or nil
end

---@param context OrgCompletionContext
---@return string[]
function OrgCompletionPropertyValues:get_results(context)
  local value_source = self:_value_source(context.line)
  if not value_source then
    return {}
  end

  return value_source(self)
end

return OrgCompletionPropertyValues
