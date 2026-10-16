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
