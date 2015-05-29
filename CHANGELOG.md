## 1.2.0 - 2015-05-29

### Fixes

Require POSIX spawn libraries immediately to combat loading race
conditions when real threads are used. POSIX spawn support for the
platform is assumed, but load errors are rescued.

## 1.1.0 - 2014-09-15

### Features

Support child process output > 64KB, parent process no longer waits for
the child before closing its write end of pipe.
