# ttbench

ttbench is a runner for [tarantool](https://github.com/tarantool/tarantool) benchmarks.

Please note, that ttbench is written on tarantool itself, so it is required to have stable tarantool built (2.4+).

## Common cli options

- -b comma-separated list of benchmarks (for install or run commands)
- -d set debug mode one, will provide extra output
- -c provide path to config file (however default config file should be OK)
- -r provide comma-separated list of benchmarks' runids (for delete or diff commands)
- -Dkey=value redefine env variables for benchmarks
- -Ckey=value redefine config values
- --help, will output verbose help message about commands and other cli options

# Commands

## install

To install benchmarks, run
```bash
$ ./ttbench install
```

This will clone benchmarks in their install directories (listed in config.lua) and build them. Extra dependencies are required for building some of them.

Please note, that some of benchmarks might not be running corectly as long as their fixes are not yet merged into their repositories' master branches.

- https://github.com/tarantool/tarantool-c.git
- https://github.com/tarantool/msgpuck.git
- https://github.com/msgpack/msgpack-c/releases/download/cpp-3.3.0/msgpack-3.3.0.tar.gz
- mvn (linkbench,ycsb)
- sqlite3 (tpch)

To reinstall benchmarks, run
```bash
$ ./ttbench -f install
```

## run

To run benchmarks, run
```bash
$ ./ttbench run
```

To run some subset of benchmarks, use -b flag
```bash
$ ./ttbench -b cbench,sysbench run
```

Please note, that to path to benchee version of tarantool is written in config.lua file. To pass another tarantool build,
you can either edit config.lua file, or use -C option
```bash
$ ./ttbench -CTARANTOOL_EXECUTABLE=/path/to/another/tarantool run
```

## diff

Every benchmark run has a runid. Benchmarks' results are stored in RESULT_DIR directory (from config.lua) under their runid.

You can diff 2 benchmark runs, by using -r cli option. For comfortable usage, you can pass 'last' as -r argument.
This will cause diff to run itself on 2 last runs.

```bash
$ ./ttbench diff -r last
```

## other

For other not so common commands consider running
```bash
$ ./ttbench --help
```
