package vsh

import "core:fmt"
import "core:log"
import "core:strings"
import "core:slice"
import "core:os"
import "core:unicode/utf8"

import "../syntax"
import zd "../0d"

Bang :: struct {}

leaf_process_init :: proc(name: string) -> ^zd.Eh {
    command_string := strings.clone(strings.trim_left(name, "$ "))
    command_string_ptr := new_clone(command_string)
    return zd.make_leaf(name, command_string_ptr, leaf_process_proc)
}

leaf_process_proc :: proc(eh: ^zd.Eh, msg: zd.Message(any), command: ^string) {
    utf8_string :: proc(bytes: []byte) -> (s: string, ok: bool) {
        s = string(bytes)
        ok = utf8.valid_string(s)
        return
    }

    send_output :: proc(eh: ^zd.Eh, port: string, output: []byte) {
        if len(output) > 0 {
            str, ok := utf8_string(output)
            if ok {
                zd.send(eh, port, str)
            } else {
                zd.send(eh, port, output)
            }
        }
    }

    switch msg.port {
    case "stdin":
        handle := process_start(command^)
        defer process_destroy_handle(handle)

        // write input, wait for finish
        {
            switch value in msg.datum {
            case string:
                bytes := transmute([]byte)value
                os.write(handle.input, bytes)
            case []byte:
                os.write(handle.input, value)
            }
            os.close(handle.input)
            process_wait(handle)
        }

        // stdout handling
        {
            stdout, ok := process_read_handle(handle.output)
            if ok {
                send_output(eh, "stdout", stdout)
            }
        }

        // stderr handling
        {
            stderr, ok := process_read_handle(handle.error)
            if ok {
                send_output(eh, "stderr", stderr)
            }

            if len(stderr) > 0 {
                str := string(stderr)
                str = strings.trim_right_space(str)
                log.error(str)
            }
        }
    }
}

collect_process_leaves :: proc(path: string, leaves: ^[dynamic]Leaf_Initializer) {
    ref_is_container :: proc(decls: []syntax.Container_Decl, name: string) -> bool {
        for d in decls {
            if d.name == name {
                return true
            }
        }
        return false
    }

    decls, err := syntax.parse_drawio_mxgraph(path)
    assert(err == nil)
    defer delete(decls)

    // TODO(z64): while harmless, this doesn't ignore duplicate process decls yet.

    for decl in decls {
        for child in decl.children {
            if ref_is_container(decls[:], child.name) {
                continue
            }

            if strings.has_prefix(child.name, "$") {
                leaf_init := Leaf_Initializer {
                    name = child.name,
                    init = leaf_process_init,
                }
                append(leaves, leaf_init)
            }
        }
    }
}

main :: proc() {
    context.logger = log.create_console_logger(
        opt={.Level, .Time, .Terminal_Color},
    )

    // load arguments
    diagram_source_file := slice.get(os.args, 1) or_else "vsh.drawio"
    main_container_name := slice.get(os.args, 2) or_else "main"

    if !os.exists(diagram_source_file) {
        fmt.println("Source diagram file", diagram_source_file, "does not exist.")
        os.exit(1)
    }

    // set up leaves
    leaves := make([dynamic]Leaf_Initializer)
    collect_process_leaves(diagram_source_file, &leaves)

    regstry := make_component_registry(leaves[:], diagram_source_file)

    // get entrypoint container
    main_container, ok := get_component_instance(regstry, main_container_name)
    fmt.assertf(
        ok,
        "Couldn't find main container with page name %s in file %s (check tab names, or disable compression?)\n",
        main_container_name,
        diagram_source_file,
    )

    // run!
    init_msg := zd.make_message("input", Bang{})
    main_container.handler(main_container, init_msg)

    fmt.println("--- Outputs ---")
    if main_container.output.len > 0 {
        iter := zd.make_fifo_iterator(&main_container.output)
        for msg in zd.fifo_iterate(&iter) {
            a := any{msg.datum, msg.datum_type_id}
            fmt.printf("%s = %#v", msg.port, a)
        }
    } else {
        fmt.println("(no output)")
    }
}
