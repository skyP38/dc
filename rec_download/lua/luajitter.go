// +build luajitter

package lua

import (
	"github.com/cannibalvox/luajitter"
)

func init() {
	NewState = newLuajitterState
}

func newLuajitterState() State {
	vm := luajitter.NewState()
	return &luajitterState{vm: vm}
}

type luajitterState struct {
	vm *luajitter.LuaState
}

func (s *luajitterState) Close() {
	s.vm.Close()
}

func (s *luajitterState) OpenLibs() {
	// luajitter не требует явной загрузки библиотек, они уже доступны.
}

func (s *luajitterState) SetGlobal(name string, fn GoFunction) error {
	wrapper := func(args []interface{}) ([]interface{}, error) {
		return fn(args)
	}
	return s.vm.SetGlobal(name, wrapper)
}

func (s *luajitterState) DoString(code string) error {
	return s.vm.DoString(code)
}

func (s *luajitterState) GetGlobal(name string) (interface{}, error) {
	return s.vm.GetGlobal(name)
}
