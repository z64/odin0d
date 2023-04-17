package demo_drawio

import "core:fmt"
import "core:strings"
import zd "../0d"

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

main :: proc() {
    leaves: []Leaf_Initializer = {
        {
            name = "Echo",
            init = proc(name: string) -> ^Eh {
                return make_leaf(name, passthrough)
            },
        },
    }

    reg := make_component_registry(leaves, "example.drawio")

    main_container, ok := get_component_instance(reg, "main")
    assert(ok, "Couldn't find main container... check the page name?")

    msg := make_message("stdin", "Hello World!")
    main_container.handler(main_container, msg)
    print_output_list(output_list(main_container))
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
