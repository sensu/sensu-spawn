## 1.4.0 - 2015-09-09

### Fixes

Added a mutex `synchronize()` around ChildProcess Unix POSIX spawn
(`start()`), as it is not thread safe, allowing safe execution on
Ruby runtimes with real threads (JRuby).

## 1.3.0 - 2015-07-09

### Other

Bumped the version of childprocess to 0.5.6, adding support for the
removal of environment variables (nil) and improved illegal thread state
logging.

## 1.2.0 - 2015-05-29

### Fixes

Require POSIX spawn libraries immediately to combat loading race
conditions when real threads are used. POSIX spawn support for the
platform is assumed, but load errors are rescued.

## 1.1.0 - 2014-09-15

### Features

Support child process output > 64KB, parent process no longer waits for
the child before closing its write end of pipe.
