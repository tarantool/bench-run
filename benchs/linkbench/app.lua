#!/usr/bin/env tarantool

local path = require('fio').dirname(arg[0])
package.path = path.."/?.lua;"..package.path
package.cpath = path.."/?.so;"..package.cpath

require('console').listen('unix/:./tarantool.sock')
require('gperftools').cpu.start('tarantool.prof')

box.cfg{
    listen = 3301;
    vinyl_memory = 256 * 1024 * 1024;
    vinyl_cache =  256 * 1024 * 1024;
    vinyl_read_threads = 1;
}

require('app_internal')
