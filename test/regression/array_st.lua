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

local function just(x) return {tag = "just", value = x} end
local nothing = {tag = "nothing"}

--------------------------------------------------------------------------------
-- Data/Array/ST.lua: move-based operations -----------------------------------

-- The ST foreigns follow the STFn convention: an STFnN entry is an N-ary
-- function that performs the effect when called and returns the result
-- directly — no inner thunk, and the export carries the `*Impl` name the
-- PureScript side declares.

-- freezeImpl / thawImpl (the move-to-fresh-table path) are independent copies.
do
  local xs = {1, 2, 3}
  local copy = ST.freezeImpl(xs)
  checkArray("freezeImpl copies", copy, {1, 2, 3})
  copy[1] = 99
  check("freezeImpl is independent", xs[1] == 1, "source mutated to " .. tostring(xs[1]))
end

do
  local xs = {1, 2, 3}
  local copy = ST.thawImpl(xs)
  checkArray("thawImpl copies", copy, {1, 2, 3})
  xs[1] = 99
  check("thawImpl is independent", copy[1] == 1, "copy mutated to " .. tostring(copy[1]))
end

-- cloneImpl (the same move-to-fresh-table path) is an independent copy.
do
  local xs = {1, 2, 3}
  local copy = ST.cloneImpl(xs)
  checkArray("cloneImpl copies", copy, {1, 2, 3})
  xs[1] = 99
  check("cloneImpl is independent", copy[1] == 1, "copy mutated to " .. tostring(copy[1]))
end

-- toAssocArrayImpl builds zero-based {index, value} records.
do
  local r = ST.toAssocArrayImpl({"a", "b"})
  check("toAssocArrayImpl builds records",
        type(r) == "table" and #r == 2 and r[1].index == 0 and r[1].value == "a" and r[2].index == 1 and r[2].value == "b",
        "got " .. tostring(r))
end

-- peekImpl returns the Maybe itself, not a thunk producing it.
do
  local r = ST.peekImpl(just, nothing, 1, {10, 20, 30})
  check("peekImpl returns the Maybe directly", type(r) == "table" and r.tag == "just" and r.value == 20, "got " .. type(r))
  check("peekImpl out of range is nothing", ST.peekImpl(just, nothing, 9, {10}) == nothing, "expected nothing")
end

-- pushAllImpl appends and reports the new length.
do
  local xs = {1, 2}
  local n = ST.pushAllImpl({3, 4, 5}, xs)
  checkArray("pushAllImpl appends", xs, {1, 2, 3, 4, 5})
  check("pushAllImpl returns length", n == 5, "got " .. tostring(n))
end

-- spliceImpl mirrors JS `xs.splice(i, howMany, ...bs)`: remove howMany
-- elements at offset i, insert bs there, mutate xs in place, and RETURN the
-- removed slice. (Issue #75 — the move-only version neither inserted nor
-- returned the removed elements.)
do
  local xs = {10, 20, 30, 40, 50}
  local removed = ST.spliceImpl(1, 1, {}, xs)
  checkArray("spliceImpl removes one, no insert", xs, {10, 30, 40, 50})
  checkArray("spliceImpl returns removed slice", removed, {20})
end

do
  local xs = {1, 2, 3, 4}
  local removed = ST.spliceImpl(0, 0, {9}, xs)
  checkArray("spliceImpl inserts, removes none", xs, {9, 1, 2, 3, 4})
  checkArray("spliceImpl removed is empty", removed, {})
end

do
  local xs = {10, 20, 30, 40, 50}
  local removed = ST.spliceImpl(1, 2, {99}, xs)
  checkArray("spliceImpl replaces two with one", xs, {10, 99, 40, 50})
  checkArray("spliceImpl returns the two removed", removed, {20, 30})
end

do
  local xs = {1, 2, 3}
  local removed = ST.spliceImpl(1, 1, {8, 9}, xs)
  checkArray("spliceImpl replaces one with two", xs, {1, 8, 9, 3})
  checkArray("spliceImpl removed single", removed, {2})
end

-- unshiftAllImpl prepends `as` to the front of `xs` (shifting the existing
-- elements right) and returns the new length. (Issue #74 — the move-only
-- version overwrote the front instead of prepending.)
do
  local xs = {1, 2}
  local n = ST.unshiftAllImpl({3, 4, 5}, xs)
  checkArray("unshiftAllImpl prepends", xs, {3, 4, 5, 1, 2})
  check("unshiftAllImpl returns length", n == 5, "got " .. tostring(n))
end

do
  local xs = {1, 2}
  local n = ST.unshiftAllImpl({}, xs)
  checkArray("unshiftAllImpl empty is a no-op", xs, {1, 2})
  check("unshiftAllImpl empty returns length", n == 2, "got " .. tostring(n))
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
