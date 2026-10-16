local Parser = require('orgmode.columns.parser')

describe('Column Parser', function()
  it('parses basic column format', function()
    local format = '%25ITEM %10Effort(Effort){:} %10CLOCKSUM'
    local result = Parser.parse(format)

    assert.are.equal(3, #result.columns)
    assert.are.equal('ITEM', result.columns[1].name)
    assert.are.equal(25, result.columns[1].width)
    assert.are.equal('ITEM', result.columns[1].title)
    assert.are.equal(true, result.columns[1].is_special)

    assert.are.equal('EFFORT', result.columns[2].name)
    assert.are.equal(10, result.columns[2].width)
    assert.are.equal('Effort', result.columns[2].title)
    assert.are.equal(':', result.columns[2].summary_type)
    assert.are.equal(false, result.columns[2].is_special)

    assert.are.equal('CLOCKSUM', result.columns[3].name)
    assert.are.equal(10, result.columns[3].width)
    assert.are.equal('CLOCKSUM', result.columns[3].title)
    assert.are.equal(true, result.columns[3].is_special)
  end)

  it('parses columns with allowed values', function()
    local format = '%Owner{Owner_ALL} %Status{Status_ALL}'
    local result = Parser.parse(format)

    assert.are.equal(2, #result.columns)
    assert.are.equal('OWNER', result.columns[1].name)
    assert.are.same({ 'Owner_ALL' }, result.columns[1].allowed_values)

    assert.are.equal('STATUS', result.columns[2].name)
    assert.are.same({ 'Status_ALL' }, result.columns[2].allowed_values)

    assert.are.same({ 'Owner_ALL' }, result.allowed_values.OWNER_ALL)
    assert.are.same({ 'Status_ALL' }, result.allowed_values.STATUS_ALL)
  end)

  it('parses columns with custom allowed values', function()
    local format = '%Approved(Approved?){[ ],[X]}'
    local result = Parser.parse(format)

    assert.are.equal(1, #result.columns)
    assert.are.equal('APPROVED', result.columns[1].name)
    assert.are.equal('Approved?', result.columns[1].title)
    assert.are.same({ '[ ]', '[X]' }, result.columns[1].allowed_values)
  end)

  it('parses numeric summary types including the "$" currency shorthand', function()
    local format = '%10Price{$} %10Total{+;%.2f}'
    local result = Parser.parse(format)

    assert.are.equal('PRICE', result.columns[1].name)
    assert.are.equal('$', result.columns[1].summary_type)
    assert.is_nil(result.columns[1].allowed_values)

    assert.are.equal('TOTAL', result.columns[2].name)
    assert.are.equal('+;%.2f', result.columns[2].summary_type)
  end)

  it('handles empty format', function()
    local result = Parser.parse('')
    assert.are.same({}, result.columns)
    assert.are.same({}, result.allowed_values)

    result = Parser.parse(nil)
    assert.are.same({}, result.columns)
    assert.are.same({}, result.allowed_values)
  end)

  it('recognizes special columns', function()
    local special = { 'ITEM', 'CLOCKSUM', 'CLOCKSUM_T', 'AGE', 'TAGS', 'TODO', 'PRIORITY', 'CATEGORY' }
    for _, name in ipairs(special) do
      local format = '%' .. name
      local result = Parser.parse(format)
      assert.are.equal(true, result.columns[1].is_special, name .. ' should be special')
    end
  end)
end)

describe('Column Format Resolution', function()
  local helpers = require('tests.plenary.helpers')

  local function create_file(lines)
    local file = helpers.create_file(lines, 'format_test.org')
    file:reload_sync()
    return file
  end

  it('resolves from headline property', function()
    local file = create_file({
      '* Task A',
      ':PROPERTIES:',
      ':COLUMNS: %ITEM %TODO',
      ':END:',
    })
    local headline = file:get_headlines()[1]
    assert.are.equal('%ITEM %TODO', Parser.get_columns_format_for_headline(headline))
  end)

  it('resolves from ancestor property', function()
    local file = create_file({
      '* Parent',
      ':PROPERTIES:',
      ':COLUMNS: %ITEM',
      ':END:',
      '** Child',
    })
    local parent = file:get_headlines()[1]
    local child = parent:get_child_headlines()[1]
    assert.are.equal('%ITEM', Parser.get_columns_format_for_headline(child))
  end)

  it('resolves from file directive', function()
    local file = create_file({
      '#+COLUMNS: %25ITEM %TAGS',
      '* Task',
    })
    local headline = file:get_headlines()[1]
    assert.are.equal('%25ITEM %TAGS', Parser.get_columns_format_for_headline(headline))
  end)

  it('returns nil when no local format exists', function()
    local file = create_file({
      '* Task A',
      '* Task B',
    })
    local headline = file:get_headlines()[1]
    assert.is_nil(Parser.get_columns_format_for_headline(headline))
  end)

  it('get_columns_for_headline falls back to global default', function()
    local file = create_file({
      '* Task A',
    })
    local headline = file:get_headlines()[1]
    local def = Parser.get_columns_for_headline(headline)
    assert.is_not_nil(def)
    assert.is_not_nil(def.columns[1])
  end)
end)
