local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; PersonRecord = {}







function get_person_name()
   if currentPerson == nil then
      return ""
   else
      return currentPerson.name
   end
end

function get_person_age()
   if currentPerson == nil then
      return 0
   else
      return currentPerson.age
   end
end

function set_person_age(age)
   if currentPerson ~= nil then
      currentPerson.age = age
   end
end

function new_person(name, age)
   currentPerson = { name = name, age = age }
end

function say_hello_from_teal(name)
   return "Hello, " .. name .. "! This is from Teal."
end

local modules = {}
local loadTimes = {}
local totalStart = os.clock()

for i = 1, 10 do
   local moduleName = "hello" .. i
   local start = os.clock()

   local module = require(moduleName)
   local endTime = os.clock()
   local loadMs = (endTime - start) * 1000
   loadTimes[i] = loadMs
   modules[i] = module

   print(string.format("Loaded %s.tl in %.3f ms", moduleName, loadMs))
end

local totalEnd = os.clock()
local totalLoadMs = (totalEnd - totalStart) * 1000

print(string.format("\nTotal loading time for 10 files: %.3f ms", totalLoadMs))
print(string.format("Average loading time per file: %.3f ms", totalLoadMs / 10))

local startTime = os.clock()
local helloModule = require("hello")

helloModule.say_hello("Gopher")
helloModule.call_teal_function()
helloModule.create_and_process("Bob", 25)

local record = helloModule.create_record("David", 35)
print("Record fields: name=" .. record.name .. ", age=" .. tostring(record.age))
print("Greet result: " .. record:greet())

print("\nAll tests passed successfully!")

local endTime = os.clock()

local loadTimeMs = (endTime - startTime) * 1000
print(string.format("Time to load hello.tl: %.3f ms", loadTimeMs))
