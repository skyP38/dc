// Package lua предоставляет интерфейс для работы с Teal
// через две библиотеки: luajit-go и luajitter
// Выбор реализации осуществляется с помощью build-тегов:
//   - luajit  -> используется github.com/folays/luajit-go
//   - luajitter -> используется github.com/cannibalvox/luajitter
package lua

// GoFunction – тип функции, которую можно зарегистрировать в Lua
// Она принимает срез аргументов (из стека Lua) и возвращает срез результатов
// или ошибку. Возвращаемые значения будут помещены в стек Lua
type GoFunction func(args []interface{}) ([]interface{}, error)

// State – интерфейс, предоставляющий основные операции с виртуальной машиной Lua
type State interface {
	// Close освобождает ресурсы, связанные с состоянием Lua
	Close()

	// OpenLibs загружает стандартные библиотеки Lua
	OpenLibs()

	// SetGlobal регистрирует Go-функцию в глобальном пространстве имён Lua
	// под указанным именем. Функция должна соответствовать типу GoFunction
	SetGlobal(name string, fn GoFunction) error

	// DoString выполняет строку кода Lua/Teal. Возвращает ошибку при неудаче
	DoString(code string) error

	// GetGlobal возвращает значение глобальной переменной Lua по имени
	// Возвращает интерфейс и ошибку, если переменная не существует
	GetGlobal(name string) (interface{}, error)
}

// NewState создаёт новое состояние Lua с реализацией, выбранной на этапе сборки.
// Функция определена в файлах с тегами (luajit.go или luajitter.go)
var NewState func() State
