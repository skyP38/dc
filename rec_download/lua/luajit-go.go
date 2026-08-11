// +build luajit

package lua

import (
	"github.com/folays/luajit-go"
)

func init() {
	NewState = newLuajitState
}

type luajitState struct {
	L *luajit.State
}

func newLuajitState() State {
	L := luajit.NewState()
	return &luajitState{L: L}
}

func (s *luajitState) Close() {
	// s.L.Close()
}

func (s *luajitState) OpenLibs() {
	s.L.OpenLibs()
}

func (s *luajitState) SetGlobal(name string, fn GoFunction) error {
	wrapper := func(L *luajit.State) int {
		top := int(L.GetTop())
		args := make([]interface{}, top+1)
		for i := top; i >= 0; i-- {
			idx := luajit.Index(top-i)
			switch L.Type(idx) {
				case luajit.LUA_TSTRING:
					args[i] = L.ToString(idx)
				case luajit.LUA_TNUMBER:
					args[i] = L.ToFloat64(idx)
				case luajit.LUA_TBOOLEAN:
					args[i] = L.ToBool(idx)
				default:
					args[i] = nil
			}
		}

		res, err := fn(args)
		if err != nil {
			L.Y_lua_pushstring(err.Error())
			panic(err)
		}

		for _, v := range res {
			L.PushAny(v)
		}
		return len(res)
	}

	s.L.FuncAdd("_G", name, wrapper)
	return nil
}

func (s *luajitState) DoString(code string) error {
	return s.L.RunString(code)
	s.L.RunStringFatal(code)
	return nil
}

func (s *luajitState) GetGlobal(name string) (interface{}, error) {
	s.L.GetGlobal(name)
	defer s.L.Pop(1)

	idx := luajit.Index(-1)
	switch s.L.Type(idx) {
		case luajit.LUA_TSTRING:
			return s.L.ToString(idx), nil
		case luajit.LUA_TNUMBER:
			return s.L.ToFloat64(idx), nil
		case luajit.LUA_TBOOLEAN:
			return s.L.ToBool(idx), nil
		default:
			return nil, nil
	}
}
