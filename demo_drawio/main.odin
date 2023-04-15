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
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
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

    top_msg := make_message("stdin", "hello!")

    main_container := component_registry["main"]
    main_container.handler(main_container, top_msg)
}
