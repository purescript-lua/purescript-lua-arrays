-- Regression guard for the Lua 5.1 FFI rewrite of the array foreign modules.
--
-- Lua 5.1 has no table.pack / table.unpack / table.move, so Data/Array.lua now
-- uses `{ unpack(...) }` and Data/Array/ST.lua uses a hand-written overlap-safe
-- `move`. These checks pin the behaviour of exactly those rewritten paths,
-- especially the two overlap directions of `move` that a naive copy gets wrong.
--
-- Run from the repo root: `lua test/regression/array_st.lua`.
local ST = dofile("src/Data/Array/ST.lua")
local A = dofile("src/Data/Array.lua")

local failures = 0

local function eqArray(a, b)
  if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end
  return true
end

local function show(a)
  local parts = {}
  for i = 1, #a do parts[i] = tostring(a[i]) end
  return "{" .. table.concat(parts, ", ") .. "}"
end

local function checkArray(name, got, want)
  if eqArray(got, want) then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. ": got " .. show(got) .. ", want " .. show(want))
  end
end

local function check(name, cond, detail)
  if cond then
    print("ok   - " .. name)
  else
    failures = failures + 1
    print("FAIL - " .. name .. ": " .. tostring(detail))
  end
end

--------------------------------------------------------------------------------
-- Data/Array/ST.lua: move-based operations -----------------------------------

-- freeze (= copyImpl, the move-to-fresh-table path) is an independent copy.
do
  local xs = {1, 2, 3}
  local copy = ST.freeze(xs)()
  checkArray("freeze copies", copy, {1, 2, 3})
  copy[1] = 99
  check("freeze is independent", xs[1] == 1, "source mutated to " .. tostring(xs[1]))
end

-- pushAllImpl appends and reports the new length.
do
  local xs = {1, 2}
  local n = ST.pushAllImpl({3, 4, 5}, xs)
  checkArray("pushAllImpl appends", xs, {1, 2, 3, 4, 5})
  check("pushAllImpl returns length", n == 5, "got " .. tostring(n))
end

-- spliceImpl shifting the tail LEFT (destination before source: forward copy).
do
  local xs = {10, 20, 30, 40, 50}
  ST.spliceImpl(1, 1, {}, xs) -- move(xs, 3, 5, 2, xs)
  checkArray("spliceImpl shift-left overlap", xs, {10, 30, 40, 50, 50})
end

-- spliceImpl shifting the tail RIGHT (destination inside source: must copy
-- backwards or it clobbers). This is the case a naive forward loop breaks.
do
  local xs = {1, 2, 3, 4}
  ST.spliceImpl(0, 0, {9}, xs) -- move(xs, 1, 4, 2, xs)
  checkArray("spliceImpl shift-right overlap", xs, {1, 1, 2, 3, 4})
end

-- sortByImpl sorts in place (it copies through move internally).
do
  local function compare(x)
    return function(y)
      if x < y then
        return -1
      elseif x > y then
        return 1
      else
        return 0
      end
    end
  end
  local function fromOrdering(o) return o end
  local xs = {3, 1, 2, 1}
  local sorted = ST.sortByImpl(compare, fromOrdering, xs)
  checkArray("sortByImpl sorts ascending", sorted, {1, 1, 2, 3})
end

-- sortByImpl is stable: records with equal keys keep their input order.
do
  local function byKey(x)
    return function(y)
      if x.k < y.k then
        return -1
      elseif x.k > y.k then
        return 1
      else
        return 0
      end
    end
  end
  local function fromOrdering(o) return o end
  -- Two elements share key 1 ("a" before "b"); a stable sort keeps a before b.
  local xs = {{k = 1, id = "a"}, {k = 0, id = "c"}, {k = 1, id = "b"}}
  ST.sortByImpl(byKey, fromOrdering, xs)
  local keys, ids = {}, {}
  for i = 1, #xs do keys[i], ids[i] = xs[i].k, xs[i].id end
  checkArray("sortByImpl orders by key", keys, {0, 1, 1})
  check("sortByImpl is stable on equal keys", ids[1] == "c" and ids[2] == "a" and ids[3] == "b",
        "got order " .. table.concat(ids, ","))
end

--------------------------------------------------------------------------------
-- Data/Array.lua: unpack-based operations ------------------------------------

local function just(x) return {tag = "just", value = x} end
local nothing = {tag = "nothing"}

-- unconsImpl splits head / tail; the tail is `{ unpack(xs, 2) }`.
do
  local function empty(_) return {tag = "empty"} end
  local function next(h) return function(t) return {tag = "cons", head = h, tail = t} end end
  local r = A.unconsImpl(empty, next, {1, 2, 3})
  check("unconsImpl head", r.head == 1, "got " .. tostring(r.head))
  checkArray("unconsImpl tail", r.tail, {2, 3})
  check("unconsImpl empty", A.unconsImpl(empty, next, {}).tag == "empty", "non-empty result")
end

-- _insertAt copies via unpack, then inserts; the source is left untouched.
do
  local src = {1, 2, 3}
  local r = A._insertAt(just, nothing, 1, 99, src)
  checkArray("_insertAt result", r.value, {1, 99, 2, 3})
  checkArray("_insertAt keeps source", src, {1, 2, 3})
  check("_insertAt out of range", A._insertAt(just, nothing, 9, 0, src).tag == "nothing", "expected nothing")
end

-- _deleteAt copies via unpack, then removes.
do
  local r = A._deleteAt(just, nothing, 1, {1, 2, 3})
  checkArray("_deleteAt result", r.value, {1, 3})
end

-- _updateAt copies via unpack, then updates one slot.
do
  local function times100(x) return x * 100 end
  local r = A._updateAt(just, nothing, 1, times100, {1, 2, 3})
  checkArray("_updateAt result", r.value, {1, 200, 3})
end

--------------------------------------------------------------------------------

if failures > 0 then error(failures .. " regression check(s) failed") end
print("purescript-lua-arrays: all FFI regression checks passed")
