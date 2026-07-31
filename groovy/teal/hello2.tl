local function say_hello(name: string)
    print("Hello from Teal to " .. name)
end

local function call_teal_function()
    local msg = say_hello_from_teal("TealUser")
    print(msg)
end

local function create_and_process(name: string, age: integer)
    new_person(name, age)

    local n = get_person_name()
    local a = get_person_age()
    print("Teal: Created Person " .. n .. ", age " .. tostring(a))

    set_person_age(a + 1)
    print("Teal: New age after increment: " .. tostring(get_person_age()))
end

local function create_record(name: string, age: integer): PersonRecord
    local rec: PersonRecord = {
        name = name,
        age = age,
        greet = function(self: PersonRecord): string
            return "Record: Hello, I'm " .. self.name .. ", age " .. tostring(self.age)
        end
    }
    return rec
end

return {
    say_hello = say_hello,
    call_teal_function = call_teal_function,
    create_and_process = create_and_process,
    create_record = create_record,
}
