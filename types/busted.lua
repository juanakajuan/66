---@meta

---@param name string
---@param fn fun()
function describe(name, fn) end

---@param name string
---@param fn fun()
function it(name, fn) end

---@param fn fun()
function before_each(fn) end

---@param fn fun()
function after_each(fn) end

---@class luassert
---@field equals fun(expected: any, actual: any, message?: any)
---@field same fun(expected: any, actual: any, message?: any)
---@field truthy fun(value: any, message?: any)
---@field is_true fun(value: any, message?: any)
---@field is_false fun(value: any, message?: any)
---@field is_nil fun(value: any, message?: any)
---@overload fun(value: any, message?: any): any

---@type luassert
assert = {
  equals = function() end,
  same = function() end,
  truthy = function() end,
  is_true = function() end,
  is_false = function() end,
  is_nil = function() end,
}
