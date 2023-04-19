package demo_drawio

import "core:fmt"
import "core:os"
import "core:strings"
import "core:mem"

import zd "../0d"
import dg "../diagram"
import process "../proc"

Eh             :: zd.Eh
Message        :: zd.Message
make_container :: zd.make_container
make_message   :: zd.make_message
make_leaf      :: zd.make_leaf
send           :: zd.send
output_list    :: zd.output_list

passthrough :: proc(eh: ^Eh, msg: Message(string)) {
    fmt.println("Echo -", eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "stdout", msg.datum)
}

Bang :: struct{}

Proc_Message :: union {
    Bang,
    string,
    process.Handle,
}

leaf_process_init :: proc(name: string) -> ^Eh {
    return make_leaf(name, leaf_process_proc)
}

leaf_process_proc :: proc(eh: ^Eh, message: Message(Proc_Message)) {
    command := eh.name[2:]

    switch message.port {
    case "bang":
        fmt.println(eh.name)
        handle := process.start(command)
        send(eh, "busy", Proc_Message(handle))
    case "stdin":
        fmt.println(eh.name)
        handle := process.start(command)
        data := transmute([]byte)message.datum.(string)
        os.write(handle.input, data)
        send(eh, "busy", Proc_Message(handle))
    case "wait":
        buf := make([]u8, 1 * mem.Megabyte)
        hnd := message.datum.(process.Handle)
        len, _ := os.read(hnd.output, buf)
        process.stop(hnd)
        send(eh, "stdout", string(buf[:len]))
    }
}

leaf_process_join_init :: proc(name: string) -> ^Eh {
    return make_leaf(name, leaf_process_join)
}

leaf_process_join :: proc(eh: ^Eh, message: Message(Proc_Message)) {
    switch message.port {
    case "handle":
        buf := make([]u8, 1 * mem.Megabyte)

        hnd := message.datum.(process.Handle)
        len, _ := os.read(hnd.output, buf)

        process.stop(hnd)

        send(eh, "stdout", string(buf[:len]))
    }
}

collect_process_leaves :: proc(path: string, leaves: ^[dynamic]Leaf_Initializer) {
    ref_is_container :: proc(decls: []Container_Decl, name: string) -> bool {
        for d in decls {
            if d.name == name {
                return true
            }
        }
        return false
    }

    inits := make([dynamic]Leaf_Initializer)
    i := 0

    pages, ok := dg.read_from_xml_file(path)
    assert(ok, "Failed parsing container XML")
    defer delete(pages)

    decls := make([dynamic]Container_Decl)
    defer delete(decls)

    for page in pages {
        decl := container_decl_from_diagram(page)
        append(&decls, decl)
    }

    for decl in decls {
        for child in decl.children {
            if ref_is_container(decls[:], child.name) {
                continue
            }

            if strings.has_prefix(child.name, "$ ") {
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
    leaves := make([dynamic]Leaf_Initializer)

    collect_process_leaves("example.drawio", &leaves)

    append(&leaves, Leaf_Initializer {
        name = "join",
        init = leaf_process_join_init,
    })

    append(&leaves, Leaf_Initializer {
        name = "debug",
        init = proc(name: string) -> ^Eh {
            debug_proc :: proc(eh: ^Eh, message: Message(string)) {
                fmt.println("DEBUG -", message.port, message.datum)
            }
            return make_leaf(name, debug_proc)
        },
    })

    reg := make_component_registry(leaves[:], "example.drawio")

    main_container, ok := get_component_instance(reg, "main")
    assert(ok, "Couldn't find main container... check the page name?")

    msg := make_message("stdin", Proc_Message(Bang{}))
    main_container.handler(main_container, msg)
    //print_output_list(output_list(main_container))
}

print_output_list :: proc(list: []zd.Message_Untyped) {
    write_rune   :: strings.write_rune
    write_string :: strings.write_string

    sb: strings.Builder
    defer strings.builder_destroy(&sb)

    write_rune(&sb, '[')
    for msg, idx in list {
        if idx > 0 {
            write_string(&sb, ", ")
        }
        a := any{msg.datum, msg.datum_type_id}
        fmt.sbprintf(&sb, "{{%s, %v}", msg.port, a)
    }
    strings.write_rune(&sb, ']')

    fmt.println(strings.to_string(sb))
}
