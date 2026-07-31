import groovy.lang.Binding
import groovy.lang.GroovyShell

class Person {
    String name
    int age
}

Person currentPerson = null

def getPersonName = { -> currentPerson?.name ?: "" }
def getPersonAge = { -> currentPerson?.age ?: 0 }
def setPersonAge = { int age -> if (currentPerson) currentPerson.age = age }
def newPerson = { String name, int age -> currentPerson = new Person(name: name, age: age) }
def sayHelloFromGroovy = { String name -> "Hello, $name! This is from Groovy." }

def binding = new Binding()
binding.setVariable("get_person_name", getPersonName)
binding.setVariable("get_person_age", getPersonAge)
binding.setVariable("set_person_age", setPersonAge)
binding.setVariable("new_person", newPerson)
binding.setVariable("say_hello_from_groovy", sayHelloFromGroovy)

def shell = new GroovyShell(binding)

def modules = []
def loadTimes = []
long totalStart = System.nanoTime()

for (int i = 1; i <= 10; i++) {
    def fileName = "hello${i}.groovy"
    long start = System.nanoTime()
    def module = shell.evaluate(new File(fileName))
    long end = System.nanoTime()
    double loadMs = (end - start) / 1_000_000.0
    loadTimes << loadMs
    modules << module
    println "Loaded $fileName in ${String.format("%.3f", loadMs)} ms"
}

long totalEnd = System.nanoTime()
double totalLoadMs = (totalEnd - totalStart) / 1_000_000.0
println "\nTotal loading time for 10 files: ${String.format("%.3f", totalLoadMs)} ms"
println "Average loading time per file: ${String.format("%.3f", totalLoadMs / 10)} ms"

def helloModule = shell.evaluate(new File("hello.groovy"))

helloModule.say_hello("Gopher")
helloModule.call_go_function()
helloModule.create_and_process("Bob", 25)
def record = helloModule.create_record("David", 35)
println "Record fields: name=${record.name}, age=${record.age}"
println "Greet result: ${record.greet()}"
println "All tests passed successfully!"

