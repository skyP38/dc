global record PersonRecord
    name: string
    age: integer
    greet: function(self: PersonRecord): string
end

global currentPerson: PersonRecord

global function get_person_name(): string
    if currentPerson == nil then
        return ""
    else
        return currentPerson.name
    end
end

global function get_person_age(): integer
    if currentPerson == nil then
        return 0
    else
        return currentPerson.age
    end
end

global function set_person_age(age: integer)
    if currentPerson ~= nil then
        currentPerson.age = age
    end
end

global function new_person(name: string, age: integer)
    currentPerson = { name = name, age = age }
end

global function say_hello_from_teal(name: string): string
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
