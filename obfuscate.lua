#!/usr/bin/env luax

-- This file is part of obfuscate.lua.
--
-- obfuscate.lua is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- obfuscate.lua is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with obfuscate.lua.  If not, see <https://www.gnu.org/licenses/>.
--
-- For further information about obfuscate.lua you can visit
-- https://cdelord.fr/obfuscate.lua

local F = require "F"
local fs = require "fs"
local crypt = require "crypt"
local term = require "term"

---------------------------------------------------------------------
-- Command line
---------------------------------------------------------------------

local cli = (function()
    local parser = require "argparse"() : name "obfuscate" : description "Lua/LuaX script obfuscator"
    parser : argument "input" : description "Input script" : args "1" : argname "input" : target "input"
    parser : option "-o" : description "Output file" : args "1" : argname "output" : target "output"
    parser : flag "-x" : description "Generate a LuaX script"
    parser : option "-k" : description "Encryption key" : args "1" : argname "key" : target "key"
    parser : flag "-b" : description "Write Lua bytecode (-bb compiles the outer chunk)" : count "0-2" : target "bytecode"
    parser : flag "-s" : description "Don't write debug information" : target "strip"
    parser : flag "-z" : description "Compress the script with lzip" : target "compress"
    return F{
        key = "“Everyone is a moon, and has a dark side which he never shows to anybody.” ― Mark Twain",
    } : patch(parser:parse(arg))
end)()

---------------------------------------------------------------------
-- Read the input script
---------------------------------------------------------------------

local input = assert(fs.read(cli.input))

---------------------------------------------------------------------
-- Remove the shebang line
---------------------------------------------------------------------

input = input:gsub("^(#!)", "--%1")

---------------------------------------------------------------------
-- Compute the encryption key
---------------------------------------------------------------------

local function chunks_of(n, s)
    local chunks = F{}
    while #s > 0 do
        chunks[#chunks+1], s = s:split_at(n)
    end
    return chunks
end

local key_size = F.floor(16 + (#input-16)*(256-16)/(4096-16))
key_size = F.max(16, F.min(256, key_size))

local key = chunks_of(key_size, input:arc4(cli.key)) : fold1(crypt.arc4)

---------------------------------------------------------------------
-- Compile the script to Lua bytecode
---------------------------------------------------------------------

if cli.bytecode >= 1 then
    local compiled_chunk = assert(load(input, "@"..cli.input))
    local bytecode = assert(string.dump(compiled_chunk, cli.strip))
    input = bytecode
end

---------------------------------------------------------------------
-- Produce a self decrypting script
---------------------------------------------------------------------

local byte = string.byte
local char = string.char
local format = string.format

local esc = {
    ["'"]  = "\\'",     -- ' must be escaped as it is embeded in single quoted strings
    ["\\"] = "\\\\",    -- \ must be escaped to avoid confusion with escaped chars
}
F.flatten{
    F.range(0, 31),     -- non printable control chars
    F.range(48, 57),    -- 0..9 must be escaped to avoid confusion decimal escape codes
    F.range(128, 255),  -- non 7-bit ASCII codes are also not printable
}
: foreach(function(b) esc[char(b)] = format("\\%d", b) end)

local function escape(s)
    return format("'%s'", s:gsub(".", esc))
end

local encrypted_script

if cli.x then

    local unlzip = ""
    if cli.compress then
        local compressed_input = input:lzip()
        if #compressed_input < #input-8 then
            input = compressed_input
            unlzip = ":unlzip()"
        end
    end

    encrypted_script = F.I { b=escape(input:arc4(key)), k=escape(key), unlzip=unlzip } [===[
return load(($(b)):unarc4$(k)$(unlzip))()
]===]

else

    local a, c = 6364136223846793005, 1
    local seed = tonumber(key:hash(), 16)
    local r = seed
    local xs = {}
    for i = 1, #input do
        local b = byte(input, i, i+1)
        r = r*a + c
        xs[i] = char(b ~ ((r>>33) & 0xff))
    end

    encrypted_script = F.I { a=a, c=c, b=escape(table.concat(xs)), seed=seed } [===[
local b,a,c,r,x,bt,ch,l,tc=$(b),$(a),$(c),$(("0x%x"):format(seed)),{},string.byte,string.char,load,table.concat;for i=1,#b do r=r*a+c x[i]=ch(bt(b,i)~((r>>33)&0xff))end;return l(tc(x))()
]===]

end

if cli.bytecode >= 2 then
    local compiled_chunk = assert(load(encrypted_script))
    local bytecode = assert(string.dump(compiled_chunk, cli.strip))
    encrypted_script = bytecode
end

---------------------------------------------------------------------
-- Add the shebang line
---------------------------------------------------------------------

encrypted_script = F.str {
    "#!/usr/bin/env ", cli.x and "luax" or "lua", "\n",
    encrypted_script,
}

---------------------------------------------------------------------
-- Save the encrypted file
---------------------------------------------------------------------

if cli.output then
    assert(fs.write_bin(cli.output, encrypted_script))
    fs.chmod(cli.output, fs.aX|fs.aR|fs.uW)

elseif not term.isatty(io.stdout) then
    io.stdout:write(encrypted_script)

else
    error "Can not write the encrypted script to stdout"
end
