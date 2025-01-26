obfuscate.lua
=============

`obfuscate.lua` hides Lua scripts in encrypted scripts.
The encrypted script are still executable by any Lua or LuaX interpreter.

> “Everyone is a moon, and has a dark side which he never shows to anybody.”
> -― Mark Twain

Disclaimer
==========

The goal of `obfuscate.lua` is actually not to hide or protect sources.
Its algorithm is very poor and cryptographically weak.
The main purpose is to avoid unintended modifications.

If you need to protect your secrets, please **DO NOT USE** `obfuscate.lua`!

Usage
=====

`obfuscate.lua` requires [LuaX](https://github.com/CDSoft/luax)
but can produce plain Lua encrypted scripts.

```
Usage: obfuscate [-h] [-o output] [-x] [-k key] [-b] [-s] [-z] input

Lua/LuaX script obfuscator

Arguments:
   input                 Input script

Options:
   -h, --help            Show this help message and exit.
   -o output             Output file
   -x                    Generate a LuaX script
   -k key                Encryption key
   -b                    Write Lua bytecode (-bb compiles the outer chunk)
   -s                    Don't write debug information
   -z                    Compress the script with lzip
```

Target
======

`obfuscate.lua` produces plain Lua scripts that can be executed by a Lua interpreter without any additional dependency.

The `-x` option makes scripts for LuaX instead of Lua.
In this case, it uses LuaX functions to decrypt the initial script.
Otherwise the script can run with any plain Lua interpreter.

Encryption
==========

The `-k` option gives the encryption key (a default key is provided by `obfuscate.lua`).

Lua and LuaX use different encryption algorithms.

Lua scripts are encrypted with a simple PRNG to "xor" script bytes.
The code to decrypt is added to the output script.

LuaX scripts are encrypted with [`crypt.arc4`](https://github.com/CDSoft/luax/blob/master/doc/crypt.md#arc4-encryption).
These scripts can only be executed with [LuaX](https://github.com/CDSoft/luax).

Bytecode
========

By default, `obfuscate.lua` stores the Lua script source in the encrypted script.

The encrypted script has two levels of code.
The first level is the input script.
The second one is the decryption code.

The option `-b` compiles the first level to Lua bytecode.
It can be used twice (`-b -b` or `-bb`) to also encrypt the second level.

The option `-s` strips the debug information from the bytecode.
It makes the output smaller but error messages will carry less information.

Compression
===========

LuaX scripts can be compressed with the `-z` option.
Sources are compressed with [`lzip`](https://github.com/CDSoft/luax/blob/master/doc/lzip.md).

Example
=======

To compile, strip, compress and encrypt `hello.lua`, targeting LuaX:

``` sh
$ obfuscate.lua -x -bb -s -z hello.lua -o hello-encrypted.lua
```

or shorter:

``` sh
$ obfuscate.lua -xbbsz hello.lua -o hello-encrypted.lua
```

`hello-encrypted.lua` can be executed by LuaX:

``` sh
$ hello-encrypted.lua       # note that the shebang line calls luax instead of lua
$ luax hello-encrypted.lua  # ignore the shebang and explicitly run the script with luax
```

License
=======

    This file is part of obfuscate.lua.

    obfuscate.lua is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    obfuscate.lua is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with obfuscate.lua.  If not, see <https://www.gnu.org/licenses/>.

    For further information about obfuscate.lua you can visit
    https://cdelord.fr/obfuscate.lua
