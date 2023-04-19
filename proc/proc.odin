package process

import "core:c"
import "core:c/libc"
import "core:strings"
import "core:bytes"
import "core:os"
import "core:fmt"

foreign import libc_ext "system:c"

Pid :: distinct i32

foreign libc_ext {
    execvp  :: proc(file: cstring, argv: [^]cstring)              -> int ---
    waitpid :: proc(pid: Pid, wstatus: rawptr, options: c.int) -> Pid ---
    fork    :: proc()                                             -> Pid ---
    getpid  :: proc()                                             -> Pid ---

    system :: proc(command: cstring) -> c.int ---


    pipe :: proc(fds: [^]os.Handle)             -> c.int ---
    dup2 :: proc(fd: os.Handle, fd2: os.Handle) -> c.int ---
    kill :: proc(pid: Pid, sig: c.int)    -> c.int ---
}

unix_pipe :: proc() -> (read: os.Handle, write: os.Handle) {
    fds: [2]os.Handle

    ptr := ([^]os.Handle)(&fds)
    err := pipe(ptr)
    errno := os.get_last_error()
    fmt.assertf(err == 0, "pipe(): %v (%s)", errno, libc.strerror(c.int(errno)))

    read = os.Handle(fds[0])
    write = os.Handle(fds[1])
    return
}

unix_reopen :: proc(fd, fd2: os.Handle) {
    err := dup2(fd, fd2)
    errno := os.get_last_error()
    fmt.assertf(err >= 0, "dup2() = %d: %v (%s)", err, errno, libc.strerror(c.int(errno)))
}

Handle :: struct {
    pid:    Pid,
    input:  os.Handle,
    output: os.Handle,
    // TODO(z64): err
}

start :: proc(command: string) -> Handle {
    command_cstr := strings.clone_to_cstring(command, context.temp_allocator)

    stdin_read, stdin_write := unix_pipe()
    stdout_read, stdout_write := unix_pipe()

    fork_pid := fork()

    if fork_pid == 0 {
        unix_reopen(stdin_read, os.Handle(0))
        unix_reopen(stdout_write, os.Handle(1))

        // TODO(z64): use another pipe to communicate exit status/errno of child
        exit_code := libc.system(command_cstr)

        os.exit(127)
    }

    return {
        pid    = fork_pid,
        input  = stdin_write,
        output = stdout_read,
    }
}

stop :: proc(hnd: Handle) {
    SIGTERM :: 15
    kill(hnd.pid, SIGTERM)
}

wait :: proc(hnd: Handle) -> (ok: bool) {
    waited_pid := waitpid(hnd.pid, nil, 0)
    assert(waited_pid == hnd.pid, "waitpid() returned different pid")
    return
}

run :: proc(command: string) {
    hnd := start(command)
    wait(hnd)
}

destroy_handle :: proc(hnd: Handle) {
    // TODO(z64): what about the other parts of the pipe...?
    os.close(hnd.input)
    os.close(hnd.output)
}
