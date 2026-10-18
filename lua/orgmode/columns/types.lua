---@alias OrgColumnSummaryType '+' | 'min' | 'max' | 'mean' | 'X' | 'X/' | '@mean' | 'est+' | string

---@class OrgColumnSpec
---@field name string
---@field width number|nil
---@field title string|nil
---@field summary_type OrgColumnSummaryType|nil
---@field allowed_values string[]|nil
---@field is_special boolean

---@class OrgColumnsDefinition
---@field columns OrgColumnSpec[]
---@field allowed_values table<string, string[]>

---@class OrgColumnViewCell
---@field headline OrgHeadline
---@field column OrgColumnSpec
---@field value string
---@field summary string|nil
---@field is_computed boolean|nil

---@class OrgColumnViewRow
---@field headline OrgHeadline
---@field cells OrgColumnViewCell[]
---@field level number
---@field is_parent boolean

---@class OrgColumnViewOpts
---@field files OrgFiles
---@field links OrgLinks|nil
---@field headlines OrgHeadline[]
---@field columns_def OrgColumnsDefinition
---@field subtree boolean|nil
---@field bufnr number|nil
---@field winid number|nil
---@field on_quit fun()|nil

---@class OrgColumnView
---@field files OrgFiles
---@field links OrgLinks|nil
---@field headlines OrgHeadline[]
---@field file OrgFile|nil
---@field subtree boolean
---@field columns OrgColumnSpec[]
---@field allowed_values table<string, string[]>
---@field rows OrgColumnViewRow[]
---@field cells OrgColumnCells
---@field bufnr number
---@field winid number
---@field ns number
---@field track_ns number
---@field current_row number
---@field current_col number
---@field original_winid number
---@field original_bufnr number
---@field _headline_to_row table<OrgHeadline, number>
---@field _clocksum_cache table<OrgHeadline, number>
---@field _clocksum_t_cache table<OrgHeadline, number>
---@field _widths number[]|nil
---@field _opened boolean|nil
---@field _original_winbar string|nil
---@field _original_modifiable boolean|nil
---@field _root_extmark_id number|nil
---@field _leave_autocmd_id number|nil
---@field _autocmd_id number|nil
---@field on_quit fun()|nil

return {}
