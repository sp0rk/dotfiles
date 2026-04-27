-- mod-version:3
-- Selection expansion inspired by IntelliJ IDEA's Ctrl+W behavior.

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local config = require "core.config"
local keymap = require "core.keymap"
local DocView = require "core.docview"

local selectionexpand = {}

config.plugins.selectionexpand = common.merge({
  -- When enabled, camelCase and PascalCase identifiers expand by subword first.
  separate_camel_case_words = true,
}, config.plugins.selectionexpand)

config.plugins.selectionexpand.config_spec = {
  name = "Selection Expand",
  {
    label = "Separate camelCase Words",
    description = "Expand camelCase and PascalCase identifiers by subword first.",
    path = "separate_camel_case_words",
    type = "toggle",
    default = true,
  },
}

local history_by_doc = setmetatable({}, { __mode = "k" })

local bracket_pairs = {
  ["("] = ")",
  ["["] = "]",
  ["{"] = "}",
}

local closing_brackets = {
  [")"] = true,
  ["]"] = true,
  ["}"] = true,
}

local block_starters = {
  ["function"] = true,
  ["if"] = true,
  ["for"] = true,
  ["while"] = true,
  ["repeat"] = true,
  ["do"] = true,
  ["class"] = true,
  ["def"] = true,
  ["struct"] = true,
  ["enum"] = true,
  ["impl"] = true,
  ["trait"] = true,
  ["interface"] = true,
  ["switch"] = true,
  ["try"] = true,
  ["catch"] = true,
}

local function line_end_col(doc, line)
  return #(doc.lines[line] or "") + 1
end

local function is_token_char(char)
  return char ~= "" and char:match("[%w_%-]") ~= nil
end

local function is_space(char)
  return char == "" or char:match("%s") ~= nil
end

local function leading_spaces(line)
  local prefix = line:match("^%s*") or ""
  return #prefix
end

local function is_blank(line)
  return not line or line:match("^%s*$") ~= nil
end

local function range_key(range)
  return table.concat(range, ":")
end

local function snapshot_selections(doc)
  local selections = {}
  for _, line1, col1, line2, col2 in doc:get_selections(false) do
    selections[#selections + 1] = { line1, col1, line2, col2 }
  end
  return selections
end

local function same_snapshot(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do
    for j = 1, 4 do
      if a[i][j] ~= b[i][j] then return false end
    end
  end
  return true
end

local function apply_selections(doc, selections)
  if #selections == 0 then return end

  local first = selections[1]
  doc:set_selections(1, first[1], first[2], first[3], first[4], false, #doc.selections)
  for i = 2, #selections do
    local sel = selections[i]
    doc:add_selection(sel[1], sel[2], sel[3], sel[4])
  end
  doc.last_selection = #selections
  doc:merge_cursors()
end

local function make_text_index(doc)
  local parts = {}
  local line_starts = {}
  local offset = 1

  for i, line in ipairs(doc.lines) do
    line_starts[i] = offset
    parts[#parts + 1] = line
    offset = offset + #line
    if i < #doc.lines then
      parts[#parts + 1] = "\n"
      offset = offset + 1
    end
  end

  local text = table.concat(parts)

  local function to_offset(line, col)
    line = math.max(1, math.min(line, #doc.lines))
    col = math.max(1, math.min(col, line_end_col(doc, line)))
    return line_starts[line] + col - 1
  end

  local function to_position(target_offset)
    target_offset = math.max(1, math.min(target_offset, #text + 1))

    local low, high = 1, #line_starts
    while low <= high do
      local mid = math.floor((low + high) / 2)
      if line_starts[mid] <= target_offset then
        low = mid + 1
      else
        high = mid - 1
      end
    end

    local line = math.max(1, high)
    local col = target_offset - line_starts[line] + 1
    return line, math.min(col, line_end_col(doc, line))
  end

  return {
    text = text,
    to_offset = to_offset,
    to_position = to_position,
  }
end

local function sorted_selection(doc, idx)
  local line1, col1, line2, col2 = doc:get_selection_idx(idx, true)
  return line1, col1, line2, col2
end

local function contains_selection(index, candidate, sel_start, sel_end)
  local start_offset = index.to_offset(candidate[1], candidate[2])
  local end_offset = index.to_offset(candidate[3], candidate[4])
  return start_offset <= sel_start and end_offset >= sel_end
    and (start_offset < sel_start or end_offset > sel_end)
    and end_offset > start_offset
end

local function add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  if not candidate then return end

  candidate[1], candidate[2] = doc:sanitize_position(candidate[1], candidate[2])
  candidate[3], candidate[4] = doc:sanitize_position(candidate[3], candidate[4])
  if not contains_selection(index, candidate, sel_start, sel_end) then return end

  local key = range_key(candidate)
  if not seen[key] then
    seen[key] = true
    candidates[#candidates + 1] = candidate
  end
end

local function char_kind(char)
  if char:match("%l") then return "lower" end
  if char:match("%u") then return "upper" end
  if char:match("%d") then return "digit" end
  return "other"
end

local function add_subwords(result, line, token_start, segment_start, segment_text)
  if segment_text == "" then return end

  local word_start = 1
  for i = 2, #segment_text do
    local prev = segment_text:sub(i - 1, i - 1)
    local current = segment_text:sub(i, i)
    local next_char = segment_text:sub(i + 1, i + 1)
    local prev_kind = char_kind(prev)
    local current_kind = char_kind(current)
    local next_kind = char_kind(next_char)

    local boundary = false
    if config.plugins.selectionexpand.separate_camel_case_words then
      if current_kind == "upper" and (prev_kind == "lower" or prev_kind == "digit") then
        boundary = true
      elseif prev_kind == "upper" and current_kind == "upper" and next_kind == "lower" then
        boundary = true
      end
    end

    if not boundary and current_kind == "digit" and prev_kind ~= "digit" then
      boundary = true
    elseif not boundary and current_kind ~= "digit" and prev_kind == "digit" then
      boundary = true
    end

    if boundary then
      local first = token_start + segment_start + word_start - 2
      local last = token_start + segment_start + i - 3
      result[#result + 1] = { line, first, line, last + 1 }
      word_start = i
    end
  end

  local first = token_start + segment_start + word_start - 2
  local last = token_start + segment_start + #segment_text - 2
  result[#result + 1] = { line, first, line, last + 1 }
end

local function word_candidates(doc, line, col)
  local text = doc.lines[line] or ""
  local result = {}
  if text == "" then return result end

  local target = nil
  if is_token_char(text:sub(col, col)) then
    target = col
  elseif col > 1 and is_token_char(text:sub(col - 1, col - 1)) then
    target = col - 1
  end

  if target then
    local first, last = target, target
    while first > 1 and is_token_char(text:sub(first - 1, first - 1)) do
      first = first - 1
    end
    while last < #text and is_token_char(text:sub(last + 1, last + 1)) do
      last = last + 1
    end

    local token = text:sub(first, last)
    local segment_start = 1
    for i = 1, #token + 1 do
      local char = token:sub(i, i)
      if char == "_" or char == "-" or i > #token then
        add_subwords(result, line, first, segment_start, token:sub(segment_start, i - 1))
        segment_start = i + 1
      end
    end

    result[#result + 1] = { line, first, line, last + 1 }
    return result
  end

  if is_space(text:sub(col, col)) and not is_space(text:sub(col - 1, col - 1)) then
    target = col - 1
  elseif not is_space(text:sub(col, col)) then
    target = col
  end

  if not target then return result end

  local first, last = target, target
  while first > 1 and not is_space(text:sub(first - 1, first - 1)) do
    first = first - 1
  end
  while last < #text and not is_space(text:sub(last + 1, last + 1)) do
    last = last + 1
  end
  result[#result + 1] = { line, first, line, last + 1 }
  return result
end

local function line_candidates(doc, line)
  local result = {
    { line, 1, line, line_end_col(doc, line) },
  }

  if line < #doc.lines then
    result[#result + 1] = { line, 1, line + 1, 1 }
  end

  return result
end

local function string_candidates(doc, line, sel_start_col, sel_end_col)
  local text = doc.lines[line] or ""
  local result = {}

  for _, quote in ipairs({ '"', "'", "`" }) do
    local opening = nil
    local escaped = false

    for col = 1, #text do
      local char = text:sub(col, col)
      if char == "\\" and not escaped then
        escaped = true
      else
        if char == quote and not escaped then
          if opening then
            if opening < sel_start_col and col + 1 >= sel_end_col then
              if opening + 1 < col then
                result[#result + 1] = { line, opening + 1, line, col }
              end
              result[#result + 1] = { line, opening, line, col + 1 }
            end
            opening = nil
          else
            opening = col
          end
        end
        escaped = false
      end
    end
  end

  return result
end

local function bracket_candidates(doc, index, sel_start, sel_end)
  local result = {}
  local stack = {}
  local text = index.text
  local quote = nil
  local escaped = false

  for offset = 1, #text do
    local char = text:sub(offset, offset)

    if quote then
      if char == "\\" and not escaped then
        escaped = true
      else
        if char == quote and not escaped then
          quote = nil
        end
        escaped = false
      end
    elseif char == '"' or char == "'" or char == "`" then
      quote = char
    elseif bracket_pairs[char] then
      stack[#stack + 1] = { char = char, offset = offset }
    elseif closing_brackets[char] then
      local opening = stack[#stack]
      if opening and bracket_pairs[opening.char] == char then
        stack[#stack] = nil
        if opening.offset < sel_start and offset + 1 >= sel_end then
          local l1, c1 = index.to_position(opening.offset + 1)
          local l2, c2 = index.to_position(offset)
          if opening.offset + 1 < offset then
            result[#result + 1] = { l1, c1, l2, c2 }
          end
          l1, c1 = index.to_position(opening.offset)
          l2, c2 = index.to_position(offset + 1)
          result[#result + 1] = { l1, c1, l2, c2 }
        end
      else
        stack = {}
      end
    end
  end

  return result
end

local function nonblank_line_near(doc, line)
  if not is_blank(doc.lines[line]) then return line end

  for distance = 1, #doc.lines do
    local up = line - distance
    local down = line + distance
    if up >= 1 and not is_blank(doc.lines[up]) then return up end
    if down <= #doc.lines and not is_blank(doc.lines[down]) then return down end
  end
  return line
end

local function indentation_candidates(doc, line)
  local result = {}
  line = nonblank_line_near(doc, line)

  local base_indent = leading_spaces(doc.lines[line] or "")
  local start_line, end_line = line, line

  while start_line > 1 do
    local prev = doc.lines[start_line - 1]
    if is_blank(prev) or leading_spaces(prev) < base_indent then break end
    start_line = start_line - 1
  end

  while end_line < #doc.lines do
    local next_line = doc.lines[end_line + 1]
    if is_blank(next_line) or leading_spaces(next_line) < base_indent then break end
    end_line = end_line + 1
  end

  if start_line < end_line then
    result[#result + 1] = { start_line, 1, end_line, line_end_col(doc, end_line) }
  end

  local parent = nil
  for row = line - 1, 1, -1 do
    local candidate = doc.lines[row]
    if not is_blank(candidate) and leading_spaces(candidate) < base_indent then
      parent = row
      break
    end
  end

  if parent then
    local parent_indent = leading_spaces(doc.lines[parent])
    local block_end = parent
    for row = parent + 1, #doc.lines do
      local candidate = doc.lines[row]
      if not is_blank(candidate) and leading_spaces(candidate) <= parent_indent then
        block_end = row - 1
        break
      end
      block_end = row
    end
    if block_end > parent then
      result[#result + 1] = { parent, 1, block_end, line_end_col(doc, block_end) }
    end
  end

  return result
end

local function keyword_block_candidate(doc, line)
  local start_line = nil

  for row = line, 1, -1 do
    local token = (doc.lines[row] or ""):match("^%s*([%a_][%w_]*)")
    if token and block_starters[token] then
      start_line = row
      break
    end
  end

  if not start_line then return nil end

  local start_indent = leading_spaces(doc.lines[start_line])
  local end_line = start_line
  for row = start_line + 1, #doc.lines do
    local text = doc.lines[row]
    local token = text:match("^%s*([%a_][%w_]*)")
    if not is_blank(text) and row > line and leading_spaces(text) <= start_indent then
      if token == "end" or token == "until" or token == "}" then
        end_line = row
      end
      break
    end
    end_line = row
  end

  if end_line > start_line then
    return { start_line, 1, end_line, line_end_col(doc, end_line) }
  end
end

local function document_candidate(doc)
  return { 1, 1, #doc.lines, line_end_col(doc, #doc.lines) }
end

local function best_expansion_for_selection(doc, index, idx)
  local line1, col1, line2, col2 = sorted_selection(doc, idx)
  local sel_start = index.to_offset(line1, col1)
  local sel_end = index.to_offset(line2, col2)
  local caret_line = line2
  local caret_col = col2
  local candidates = {}
  local seen = {}

  for _, candidate in ipairs(word_candidates(doc, caret_line, caret_col)) do
    add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  end

  for _, candidate in ipairs(string_candidates(doc, caret_line, col1, col2)) do
    add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  end

  for _, candidate in ipairs(bracket_candidates(doc, index, sel_start, sel_end)) do
    add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  end

  for _, candidate in ipairs(line_candidates(doc, caret_line)) do
    add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  end

  for _, candidate in ipairs(indentation_candidates(doc, caret_line)) do
    add_candidate(candidates, seen, doc, index, candidate, sel_start, sel_end)
  end

  add_candidate(candidates, seen, doc, index, keyword_block_candidate(doc, caret_line), sel_start, sel_end)
  add_candidate(candidates, seen, doc, index, document_candidate(doc), sel_start, sel_end)

  table.sort(candidates, function(a, b)
    local a_start = index.to_offset(a[1], a[2])
    local a_end = index.to_offset(a[3], a[4])
    local b_start = index.to_offset(b[1], b[2])
    local b_end = index.to_offset(b[3], b[4])
    local a_len = a_end - a_start
    local b_len = b_end - b_start
    if a_len ~= b_len then return a_len < b_len end
    return a_start > b_start
  end)

  return candidates[1] or { line1, col1, line2, col2 }
end

function selectionexpand.expand(doc)
  doc = doc or (core.active_view and core.active_view.doc)
  if not doc then return end

  local before = snapshot_selections(doc)
  local index = make_text_index(doc)
  local after = {}

  for idx = 1, #before do
    after[#after + 1] = best_expansion_for_selection(doc, index, idx)
  end

  if same_snapshot(before, after) then return end

  local history = history_by_doc[doc]
  if not history or history.change_id ~= doc:get_change_id() then
    history = { change_id = doc:get_change_id(), stack = {} }
    history_by_doc[doc] = history
  end

  history.stack[#history.stack + 1] = before
  apply_selections(doc, after)
end

function selectionexpand.shrink(doc)
  doc = doc or (core.active_view and core.active_view.doc)
  if not doc then return end

  local history = history_by_doc[doc]
  if not history or history.change_id ~= doc:get_change_id() or #history.stack == 0 then
    return
  end

  local previous = history.stack[#history.stack]
  history.stack[#history.stack] = nil
  apply_selections(doc, previous)
end

command.add(DocView, {
  ["selectionexpand:expand"] = function(doc_view)
    selectionexpand.expand(doc_view.doc)
  end,
  ["selectionexpand:shrink"] = function(doc_view)
    selectionexpand.shrink(doc_view.doc)
  end,
})

keymap.add {
  ["ctrl+w"] = "selectionexpand:expand",
  ["ctrl+shift+w"] = "selectionexpand:shrink",
}

return selectionexpand
