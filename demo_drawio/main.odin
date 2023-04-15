package demo_drawio

import "core:fmt"
import "core:strings"
import zd "../0d"

Eh             :: zd.Eh
Message        :: zd.Message
make_container :: zd.make_container
make_leaf      :: zd.make_leaf
send           :: zd.send
output_list    :: zd.output_list

passthrough :: proc(eh: ^Eh, msg: Message(string)) {
    fmt.println("Echo -", eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "stdout", msg.datum)
}

main :: proc() {
    component_registry: Component_Registry

    register_leaves(&component_registry, {
        make_leaf("A", passthrough),
        make_leaf("B", passthrough),
        make_leaf("C", passthrough),
        make_leaf("D", passthrough),
    })

    register_containers(&component_registry, "example.drawio")

    main_container := component_registry["main"]
    main_container.handler(main_container, {"stdin", "hello!"})
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
        fmt.sbprintf(&sb, "{{%s, %v}", msg.port, msg.datum)
    }
    strings.write_rune(&sb, ']')

    fmt.println(strings.to_string(sb))
}
