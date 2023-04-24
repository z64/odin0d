package demo_drawio

import "core:fmt"
import "core:strings"
import zd "../0d"

Eh                :: zd.Eh
Message           :: zd.Message
make_container    :: zd.make_container
make_message      :: zd.make_message
make_leaf         :: zd.make_leaf
send              :: zd.send
print_output_list :: zd.print_output_list

leaf_echo_init :: proc(name: string) -> ^Eh {
    @(static) echo_counter := 0
    echo_counter += 1

    name := fmt.aprintf("Echo (ID:%d)", echo_counter)
    return make_leaf(name, leaf_echo_proc)
}

leaf_echo_proc :: proc(eh: ^Eh, msg: Message(string)) {
    fmt.println(eh.name, "/", msg.port, "=", msg.datum)
    send(eh, "output", msg.datum)
}

main :: proc() {
    leaves: []Leaf_Initializer = {
        {
            name = "Echo",
            init = leaf_echo_init,
        },
    }

    reg := make_component_registry(leaves, "example.drawio")

    fmt.println("--- Diagram: Sequential Routing ---")
    {
        main_container, ok := get_component_instance(reg, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("seq", "Hello Sequential!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }

    fmt.println("--- Diagram: Parallel Routing ---")
    {
        main_container, ok := get_component_instance(reg, "main")
        assert(ok, "Couldn't find main container... check the page name?")

        msg := make_message("par", "Hello Parallel!")
        main_container.handler(main_container, msg)
        print_output_list(main_container)
    }
}
