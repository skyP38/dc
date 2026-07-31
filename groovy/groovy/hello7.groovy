def say_hello = { String name ->
    println "Hello from Groovy script to $name"
}

def call_go_function = {
    def msg = say_hello_from_groovy("GroovyUser")
    println msg
}

def create_and_process = { String name, int age ->
    new_person(name, age)
    def n = get_person_name()
    def a = get_person_age()
    println "Groovy: Created Person $n, age $a"
    set_person_age(a + 1)
    println "Groovy: New age after increment: ${get_person_age()}"
}

def create_record = { String name, int age ->
    def rec = [name: name, age: age]
    rec.greet = { -> "Record: Hello, I'm ${rec.name}, age ${rec.age}" }
    return rec
}

[
    say_hello: say_hello,
    call_go_function: call_go_function,
    create_and_process: create_and_process,
    create_record: create_record
]
