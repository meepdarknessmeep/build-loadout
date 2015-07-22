
-- http://industriousone.com/scripting-reference --
-- https://bitbucket.org/premake/premake-dev/wiki --

function checkdir(dir)
	if not os.isdir(dir) then
		error("Directory does not exist: "..dir)
	end
end


function dbg_hook(name)
	local f=_G[name]
	_G[name] = function(a,...)
		if type(a)=="string" then
			--print(name,"",a,...)
		else
			--print(name,"",unpack(a))
		end
		return f(a,...)
	end
end

dbg_hook "links" 
dbg_hook "targetdir" 
dbg_hook "location" 
dbg_hook "libdirs" 
dbg_hook "configuration"
dbg_hook "flags" 
dbg_hook "solution" 
dbg_hook "defines" 
dbg_hook "includedirs" 
dbg_hook "linkoptions" 
dbg_hook "project" 
dbg_hook "files" 
dbg_hook "targetname" 

local function fixdir(dir,nocheck) 
	dir = path.getabsolute(dir) 
	if not nocheck then
		checkdir(dir)
	end
	return dir
end

--Relative paths
GARRYSMOD_INCLUDES_PATH	= fixdir "gmod-module-base/include"
BACKWARDS_HEADERS 		= fixdir "backwards_headers"
HOOKING 				= fixdir "hooking"
SIGSCANNING 			= fixdir "sigscanning"
SOURCE_SDK				= fixdir "source-sdk-2013/mp/src"
STEAMWORKS_SDK			= fixdir "steamworks"

PROJECT_FOLDER = os.get() .. "/" .. _ACTION

SOURCE_SDK_INCLUDES={
	SOURCE_SDK.."/public",
	SOURCE_SDK.."/public/engine",
	SOURCE_SDK.."/common",
	SOURCE_SDK.."/public/vstdlib",
	SOURCE_SDK.."/public/steam",
	SOURCE_SDK.."/public/tier0",
	SOURCE_SDK.."/public/tier1",
	SOURCE_SDK.."/tier1",
	SOURCE_SDK.."/public/game/server",
	SOURCE_SDK.."/game/shared",
	SOURCE_SDK.."/game/server",
	SOURCE_SDK.."/game/client",
}

function SOURCE_SDK_LINKS()
	local cfg = configuration()
	configuration 		"windows"
	links{"tier0","tier1","tier2","tier3","mathlib","steam_api","vstdlib"}
	
	configuration 		"linux"
	linkoptions { -- :(
		SOURCE_SDK.."/lib/public/linux32/libtier0.so",
		SOURCE_SDK.."/lib/public/linux32/tier1.a",
		SOURCE_SDK.."/lib/public/linux32/tier2.a",
		SOURCE_SDK.."/lib/public/linux32/tier3.a",
		SOURCE_SDK.."/lib/public/linux32/mathlib.a",
	}
	links {"steam_api"}
	configuration(cfg.terms)
end

local include_helpers = {
	
	source_sdk={
		func = function(_)		
			libdirs{
				SOURCE_SDK.."/lib/public/linux32",
				SOURCE_SDK.."/lib/linux32",
				SOURCE_SDK.."/lib/public"
			}
			includedirs(SOURCE_SDK_INCLUDES)
		end,
	},
	gmod_sdk={
		func = function(_)
			includedirs{GARRYSMOD_INCLUDES_PATH}	
		end,
	},	
	
	backwards_headers={
		func = function(_)
			includedirs{BACKWARDS_HEADERS}
			libdirs{BACKWARDS_HEADERS}
		end,
	},
	
	hooking={
		func = function(_,i)
			includedirs{HOOKING}
			if i then
				files{HOOKING..'/hde.cpp'}
			end
		end,
	},
	
	sigscanning={
		func = function(_,i)
			includedirs{SIGSCANNING}
			if i then
				configuration 		"windows"
				files{SIGSCANNING..'/sigscan.cpp'}
				configuration 		"linux"
				files{SIGSCANNING..'/memutils.cpp'}
			end
		end,
	},
	
	steamworks={
		func = function(_,i)
			includedirs{STEAMWORKS_SDK..'/public'}
			includedirs{STEAMWORKS_SDK..'/public/steam'}
			if i then
				libdirs	{
					STEAMWORKS_SDK..'/redistributable_bin',
					STEAMWORKS_SDK..'/redistributable_bin/linux32'
				}
			end
		end,
	},
	
	
}

function INCLUDES(what)
	local t = include_helpers[what]
	if not t then error("Not found: "..what) end
	local included = t.included
	print("Including "..what,included and "REINCLUDE!?!?" or "")
	t:func(included)
	t.included = true
	--Should we ?
	--configuration 		{}
end
function IsIncluded(what)
	local t = include_helpers[what]
	if not t then error("Not found: "..what) end
	local included = t.included
	return included or false
end
local runtime_required
function RequireRuntime()
	runtime_required = true
end

function SOLUTION(name)
	_SOLUTION_NAME=name
	solution	(name)
	language	("C++")
	location	(PROJECT_FOLDER)
	targetdir	"Release"
	
	if platforms then
		platforms { "x32" }
	end
	
	if optimize then
		optimize"On"
	end
	flags		{"NoPCH","Symbols"}
	
	if vectorextensions then
		vectorextensions "SSE2"
	else
		flags {"EnableSSE2","EnableSSE"}
	end
	
	if not runtime_required then
		flags	{"StaticRuntime"}
	end
	
	configurations
	{ 
		"Release"
	}
	
end

local defaultlibs_required
function RequireDefaultlibs()
	defaultlibs_required = true
end
function WINDOWS()
	configuration	("windows")
	defines		{"COMPILER_MSVC32","WIN32","_WIN32","_WINDOWS","_WIN32_WINNT=0x0501"}		
	defines 	{'SERVER_BIN="server.dll"'}
	if not defaultlibs_required then
		linkoptions	{ "/nodefaultlib:\"libcmt\"", "/nodefaultlib:\"libcmtd\"" }
	end
end

function LINUX()
	configuration	("linux")
	defines		{"COMPILER_GCC","POSIX","_POSIX","LINUX","_LINUX","GNUC","NO_MALLOC_OVERRIDE"}
	linkoptions	{"-Wl,-z,defs"}
	links		{"rt","dl"}
end


function PROJECT()
	project(_SOLUTION_NAME)
	targetname(_SOLUTION_NAME)
	
	kind	("SharedLib")		
	defines	{
		"GMMODULE",
		--"NO_HOOK_MALLOC",
		--LINUX? "NO_MALLOC_OVERRIDE",
		--"SOURCE_SDK=1",
		--"CLIENT_DLL",
		"VERSION_SAFE_STEAM_API_INTERFACES",
		"VECTOR",
		--"NO_STRING_T", -- breaks cbase.h for example
		--"NO_SDK",
		"_CRT_NONSTDC_NO_DEPRECATE",
		"_CRT_SECURE_NO_DEPRECATE",
		"RAD_TELEMETRY_DISABLED",
		"PROTECTED_THINGS_ENABLE",
		--"strncpy=use_Q_strncpy_instead",
		--"_snprintf=use_Q_snprintf_instead",
		--"fopen=dont_use_fopen",
	}
	
	files	{"src/**.cpp"}
	
	targetprefix(_SOLUTION_NAME:sub(1,5) ~= "gmsv_" and _SOLUTION_NAME:sub(1,5) ~= "gmcl_" and "gm_" or "")
	
	if IsIncluded"backwards_headers" then
		files {BACKWARDS_HEADERS.."/*.cpp"}
	end
	
	configuration 			"windows"
	targetsuffix 		"_win32"
	
	configuration 			"linux"
	targetsuffix 		"_linux"
	targetextension 	".dll"
	postbuildcommands { "strip --keep-file-symbols --strip-debug -p %{cfg.linktarget.relpath}" }
	
	project(_SOLUTION_NAME)
	
end

function links_static(what)
	linkoptions{"-Wl,-Bstatic,-l"..what..",-Bdynamic"}
end
