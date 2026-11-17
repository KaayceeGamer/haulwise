import sys, lupa.lua51 as L
lua = L.LuaRuntime(unpack_returned_tuples=True)
lua.globals().DIR = sys.argv[1]
lua.execute(open(sys.argv[2] + "/mock.lua").read())
lua.execute(open(sys.argv[2] + "/scenario.lua").read())
lua.execute(open(sys.argv[2] + "/scenario2.lua").read())
lua.execute(open(sys.argv[2] + "/scenario3.lua").read())
lua.execute(open(sys.argv[2] + "/scenario4.lua").read())
