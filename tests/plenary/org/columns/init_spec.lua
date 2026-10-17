local helpers = require('tests.plenary.helpers')
local config = require('orgmode.config')
local Parser = require('orgmode.columns.parser')
local ColumnView = require('orgmode.columns.init')

describe('ColumnView', function()
  ---@param lines string[]
  ---@return OrgColumnView, OrgFile, OrgHeadline
  local function create_view(lines)
    -- The previous test may have modified its buffer, which would make `:edit`
    -- refuse to open the next fixture.
    vim.bo.modified = false
    local file = helpers.create_file(lines, 'columns.org')
    file:reload_sync()
    local headline = file:get_headlines()[1]
    local columns_def = Parser.get_columns_for_headline(headline, require('orgmode').files)
    local headlines = { headline }
    if headline:has_child_headlines() then
      vim.list_extend(headlines, headline:get_child_headlines())
    end
    local view = ColumnView:new({
      files = require('orgmode').files,
      headlines = headlines,
      columns_def = columns_def,
      bufnr = file:bufnr(),
    })
    return view, file, headline
  end

  it('builds rows for a headline tree', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %Owner{Owner_ALL}',
      ':Owner_ALL: Alice, Bob',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':Owner: Alice',
      ':END:',
    })

    assert.are.equal(2, #view.rows)
    assert.are.equal('Parent', view.rows[1].headline:get_title())
    assert.are.equal('Child', view.rows[2].headline:get_title())
    assert.are.equal('Alice', view.rows[2].cells[2].value)
  end)

  it('looks up property columns case-insensitively', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Owner{Owner_ALL}',
      ':Owner_ALL: Alice, Bob',
      ':owner: Bob',
      ':END:',
    })

    assert.are.equal('Bob', view.rows[1].cells[1].value)
  end)

  it('computes summaries from child values', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Effort{+}',
      ':END:',
      '** Child 1',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
      '** Child 2',
      ':PROPERTIES:',
      ':Effort: 0:30',
      ':END:',
    })

    assert.are.equal('90', view.rows[1].cells[1].summary)
  end)

  it('summarizes a duration column with "@mean"', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Effort{@mean}',
      ':END:',
      '** Child 1',
      ':PROPERTIES:',
      ':Effort: 0:30',
      ':END:',
      '** Child 2',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
    })

    assert.are.equal('0:45', view.rows[1].cells[1].summary)
  end)

  it('toggles checkbox cell values in both directions', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Approved(Approved?){[ ],[X]}',
      ':approved: [X]',
      ':END:',
    })

    assert.are.equal('[X]', view.rows[1].cells[1].value)

    view.current_row = 1
    view.current_col = 1
    view:toggle_or_quit()
    assert.are.equal('[ ]', view.rows[1].cells[1].value)
    assert.are.equal('[ ]', view.rows[1].headline:get_property('approved'))

    view:toggle_or_quit()
    assert.are.equal('[X]', view.rows[1].cells[1].value)
    assert.are.equal('[X]', view.rows[1].headline:get_property('approved'))
  end)

  it('quits instead of cycling TODO when toggling on the ITEM column', function()
    local view = create_view({
      '* TODO Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 1
    view:open()

    assert.are.equal('TODO', view.rows[1].headline:get_todo())
    view:toggle_or_quit()

    assert.are.equal('TODO', view.rows[1].headline:get_todo())
    assert.is_false(view._opened)
  end)

  it('stores edited allowed values in the entry that defines them', function()
    local view = create_view({
      '* Grandparent',
      ':PROPERTIES:',
      ':COLUMNS: %10Status{Status_ALL}',
      ':Status_ALL: ToDo,Done',
      ':END:',
      '** Parent',
      ':PROPERTIES:',
      ':END:',
      '*** Child',
      ':PROPERTIES:',
      ':END:',
    })

    view.current_row = 3
    view.current_col = 1

    local original_input = vim.fn.input
    vim.fn.input = function()
      return 'ToDo,In progress,Done'
    end

    local ok, err = pcall(function()
      view:edit_allowed()
    end)
    vim.fn.input = original_input

    assert.is_true(ok, err)
    assert.are.equal('ToDo,In progress,Done', view.rows[1].headline:get_own_properties()['status_all'])
    assert.is_nil(view.rows[3].headline:get_own_properties()['status_all'])
    assert.are.equal(
      'ToDo,In progress,Done',
      view.allowed_values['STATUS_ALL'] and table.concat(view.allowed_values['STATUS_ALL'], ',') or nil
    )
  end)

  it('stores edited allowed values in the first entry when none is defined', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Status{Status_ALL}',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':END:',
    })

    view.current_row = 2
    view.current_col = 1

    local original_input = vim.fn.input
    vim.fn.input = function()
      return 'ToDo,Done'
    end
    view:edit_allowed()
    vim.fn.input = original_input

    assert.are.equal('ToDo,Done', view.rows[1].headline:get_own_properties()['status_all'])
    assert.is_nil(view.rows[2].headline:get_own_properties()['status_all'])
  end)

  it('refuses to edit allowed values for special columns', function()
    local view = create_view({
      '* TODO Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %TODO',
      ':END:',
    })

    view.current_row = 1
    view.current_col = 2

    local utils = require('orgmode.utils')
    local original_echo = utils.echo_info
    local messages = {}
    utils.echo_info = function(msg)
      table.insert(messages, msg)
    end
    local original_input = vim.fn.input
    vim.fn.input = function()
      error('input must not be called for special columns')
    end
    local ok, err = pcall(function()
      view:edit_allowed()
    end)
    vim.fn.input = original_input
    utils.echo_info = original_echo

    assert.is_true(ok, err)
    assert.is_truthy(messages[1] and messages[1]:find('TODO', 1, true))
    assert.is_nil(view.rows[1].headline:get_own_properties()['todo_all'])
  end)

  it('narrows columns that do not have an explicit width', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %Owner{Owner_ALL}',
      ':Owner_ALL: Alice',
      ':Owner: Bob',
      ':END:',
    })

    assert.is_nil(view.rows[1].cells[1].column.width)

    view.current_row = 1
    view.current_col = 1
    view:narrow_column()

    assert.are.equal(9, view.rows[1].cells[1].column.width)
  end)

  it('renders a time summary for the ":" summary type', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Effort(Effort){:}',
      ':END:',
      '** Child 1',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
      '** Child 2',
      ':PROPERTIES:',
      ':Effort: 2:30',
      ':END:',
    })

    assert.are.equal('3:30', view.rows[1].cells[1].summary)
  end)

  it('highlights a summary cell as current when it is selected', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10ITEM %10Effort(Effort){:}',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
    })

    -- Effort cell is rendered after the border/item/border parts
    view.current_row = 1
    view.current_col = 1
    local not_current = view:_build_virt_text(view.rows[1], 1)[4]
    assert.are.equal('@org.column.summary', not_current[2])
    assert.is_truthy(not_current[1]:find('Σ='))

    view.current_col = 2
    local current = view:_build_virt_text(view.rows[1], 1)[4]
    assert.are.equal('@org.column.current', current[2])
    assert.is_truthy(current[1]:find('Σ='))
  end)

  it('keeps a summary cell the same width as regular cells', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10ITEM %10Effort(Effort){:}',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
    })

    local parent_cell = view:_build_virt_text(view.rows[1], 1)[4][1]
    local child_cell = view:_build_virt_text(view.rows[2], 2)[4][1]

    assert.are.equal(vim.api.nvim_strwidth(child_cell), vim.api.nvim_strwidth(parent_cell))
  end)

  it('updates parent summaries when a child value changes', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10ITEM %10Effort(Effort){:}',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':Effort: 1:00',
      ':END:',
    })

    assert.are.equal('1:00', view.rows[1].cells[2].summary)

    view.current_row = 2
    view.current_col = 2
    view:_set_cell_value(view.rows[2].cells[2], '5:00')

    assert.are.equal('5:00', view.rows[2].cells[2].value)
    assert.are.equal('5:00', view.rows[1].cells[2].summary)
  end)

  it('stays active when a floating popup (help) is opened', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Owner{Owner_ALL}',
      ':Owner_ALL: Alice',
      ':Owner: Bob',
      ':END:',
    })

    local quit_called = false
    view.on_quit = function()
      quit_called = true
    end
    view:open()

    local Help = require('orgmode.objects.help')
    Help.show('column_view')
    vim.wait(50)

    if Help.win and vim.api.nvim_win_is_valid(Help.win) then
      vim.api.nvim_win_close(Help.win, true)
    end
    vim.wait(50)

    assert.is_false(quit_called)

    local has_mapping = false
    for _, m in ipairs(vim.api.nvim_buf_get_keymap(view.bufnr, 'n')) do
      if m.lhs == '<lt>' then
        has_mapping = true
      end
    end
    assert.is_true(has_mapping)

    view:quit()
  end)

  it('registers default mappings for all column view actions', function()
    local maps = config:get_mappings('column_view')
    assert.are.equal('<', maps.narrow_column.default_map)
    assert.are.equal('>', maps.widen_column.default_map)
    assert.are.equal('<M-Left>', maps.move_column_left.default_map)
    assert.are.equal('<M-Right>', maps.move_column_right.default_map)
    assert.are.equal('<S-M-Left>', maps.delete_column.default_map)
    assert.are.equal('<S-M-Right>', maps.insert_column.default_map)
    assert.are.equal('g?', maps.show_help.default_map)
    assert.are.same({ '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' }, maps.select_value.default_map)
  end)

  it('includes column view mappings in help content', function()
    local Help = require('orgmode.objects.help')
    Help._generate_tree()
    local content = table.concat(Help.prepare_content('column_view'), '\n')
    assert.is_truthy(content:find('Column View', 1, true))
    assert.is_truthy(content:find('Quit column view', 1, true))
  end)

  it('sums CLOCK intervals across the subtree for CLOCKSUM', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10CLOCKSUM',
      ':END:',
      ':LOGBOOK:',
      'CLOCK: [2000-01-03 Mon 08:00]--[2000-01-03 Mon 09:00] => 1:00',
      ':END:',
      '** Child',
      ':LOGBOOK:',
      'CLOCK: [2000-01-03 Mon 10:00]--[2000-01-03 Mon 12:00] => 2:00',
      ':END:',
    })

    assert.are.equal('3:00', view.rows[1].cells[1].value)
    assert.are.equal('2:00', view.rows[2].cells[1].value)
  end)

  it('restricts CLOCKSUM_T to clocks from today', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10CLOCKSUM_T',
      ':END:',
      '** Past child',
      ':LOGBOOK:',
      'CLOCK: [2000-01-03 Mon 10:00]--[2000-01-03 Mon 12:00] => 2:00',
      ':END:',
    })

    assert.are.equal('', view.rows[1].cells[1].value)
    assert.are.equal('', view.rows[2].cells[1].value)
  end)

  it('renders the age column from the CREATED property', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10AGE',
      ':CREATED: 2020-01-01 Wed',
      ':END:',
    })

    assert.is_truthy(view.rows[1].cells[1].value:match('%d+%s*[dwmy]'))
  end)

  it('toggles the view off when invoked again while active', function()
    local org = require('orgmode')
    local file = helpers.create_file({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10ITEM %Owner',
      ':END:',
      '** Child',
      ':PROPERTIES:',
      ':Owner: Alice',
      ':END:',
    }, 'toggle.org')
    file:reload_sync()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local mappings = org.org_mappings
    mappings:org_columns()
    assert.is_not_nil(mappings.column_view)

    mappings:org_columns()
    assert.is_nil(mappings.column_view)
  end)

  it('opens a whole-file view when point is before the first headline', function()
    local org = require('orgmode')
    local file = helpers.create_file({
      '#+COLUMNS: %10ITEM %Owner',
      '',
      '* First',
      ':PROPERTIES:',
      ':Owner: Alice',
      ':END:',
      '* Second',
      ':PROPERTIES:',
      ':Owner: Bob',
      ':END:',
    }, 'whole-file.org')
    file:reload_sync()
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    local mappings = org.org_mappings
    mappings:org_columns()
    assert.is_not_nil(mappings.column_view)
    assert.are.equal(2, #mappings.column_view.rows)
    assert.are.equal('First', mappings.column_view.rows[1].headline:get_title())
    assert.are.equal('Second', mappings.column_view.rows[2].headline:get_title())

    mappings:org_columns()
    assert.is_nil(mappings.column_view)
  end)

  it('selects a specific TODO keyword by number', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %TODO',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 2

    view:select_value(2)
    assert.are.equal('DONE', view.rows[1].headline:get_todo())

    view:select_value(1)
    assert.are.equal('TODO', view.rows[1].headline:get_todo())
  end)

  it('selects a specific priority by number', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %PRIORITY',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 2

    view:select_value(3)
    assert.are.equal('C', view.rows[1].headline:get_priority())

    view:select_value(1)
    assert.are.equal('A', view.rows[1].headline:get_priority())
  end)

  it('selects a value using the number key mappings', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %TODO',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 2
    view:open()

    vim.api.nvim_feedkeys('2', 'x', false)
    assert.are.equal('DONE', view.rows[1].headline:get_todo())

    vim.api.nvim_feedkeys('1', 'x', false)
    assert.are.equal('TODO', view.rows[1].headline:get_todo())

    view:quit()
  end)

  it('selects the 10th value with the 0 key', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Owner{Owner_ALL}',
      ':Owner_ALL: A,B,C,D,E,F,G,H,I,J',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 1
    view:open()

    vim.api.nvim_feedkeys('0', 'x', false)
    assert.are.equal('J', view.rows[1].headline:get_property('owner'))

    view:quit()
  end)

  it('cycles TODO from the empty state to the first keyword', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %TODO',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 2

    view:next_value()
    assert.are.equal('TODO', view.rows[1].headline:get_todo())

    view:next_value()
    assert.are.equal('DONE', view.rows[1].headline:get_todo())

    view:prev_value()
    assert.are.equal('TODO', view.rows[1].headline:get_todo())
  end)

  it('renders the header in the window bar and restores it on quit', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %10Owner %12Status',
      ':END:',
    })
    vim.wo.winbar = 'ORIGINAL_WINBAR'
    view:open()

    local winbar = vim.wo[view.winid].winbar
    assert.is_truthy(winbar:find('Owner', 1, true))
    assert.is_truthy(winbar:find('Status', 1, true))

    view:quit()
    assert.are.equal('ORIGINAL_WINBAR', vim.wo[view.winid].winbar)
  end)

  it('locks the buffer while the view is open and restores it on quit', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %25ITEM %10Owner{Owner_ALL}',
      ':Owner_ALL: Alice, Bob',
      ':END:',
    })
    view.current_row = 1
    view.current_col = 2

    local bufnr = view.bufnr
    assert.is_true(vim.bo[bufnr].modifiable)

    view:open()
    assert.is_false(vim.bo[bufnr].modifiable)

    view:select_value(2)
    assert.are.equal('Bob', view.rows[1].headline:get_property('owner'))
    assert.is_false(vim.bo[bufnr].modifiable)

    view:quit()
    assert.is_true(vim.bo[bufnr].modifiable)
  end)

  it('skips rows hidden by a closed fold when navigating', function()
    local view = create_view({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %ITEM',
      ':END:',
      '** One',
      '** Two',
    })
    assert.are.equal(3, #view.rows)

    vim.api.nvim_set_current_buf(view.bufnr)
    vim.cmd('setlocal foldmethod=manual')
    vim.cmd('normal! zE')
    vim.cmd('5,6fold')

    -- The fold's first line (One) stays visible, its content (Two) does not.
    assert.is_true(view:_is_row_visible(view.rows[2]))
    assert.is_false(view:_is_row_visible(view.rows[3]))

    view.current_row = 1
    view:move_down()
    assert.are.equal(2, view.current_row)
    view:move_down()
    assert.are.equal(2, view.current_row)

    vim.cmd('normal! zE')
    vim.cmd('setlocal foldmethod=expr')
  end)
end)
