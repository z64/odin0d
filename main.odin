package main

import "core:fmt"
import "core:testing"
import "core:container/queue"

// ----------------------------------------------------------------------------- UTILS

inspect :: proc{
    inspect_message,
    inspect_eh,
    inspect_container,
}

inspect_message :: proc(m: Message) -> string {
    return fmt.tprintf("<%s,%v>", m.port, m.datum)
}

inspect_eh :: proc(eh: Eh) -> string {
    return fmt.tprintf("[Eh/%s]", eh.name)
}

inspect_container :: proc(container: Container) -> string {
    return fmt.tprintf("[Container/%s]", container.name)
}

// Odin corelib currently doesn't provide this
Queue_Iterator :: struct($T: typeid) {
    q:   ^queue.Queue(T),
    idx: int,
}

make_queue_iterator :: proc(q: ^queue.Queue($T)) -> Queue_Iterator(T) {
    return {q, 0}
}

queue_iterate :: proc(iter: ^Queue_Iterator($T)) -> (item: T, idx: int, ok: bool) {
    i := (uint(iter.idx)+iter.q.offset) % len(iter.q.data)
    if i < iter.q.len {
        ok = true
        idx = iter.idx
        iter.idx += 1
        #no_bounds_check item = iter.q.data[i]
    }
    return
}

@(test)
test_queue_iterate :: proc(x: ^testing.T) {
    q := queue.Queue(int){}

    for i in 1..=10 {
        queue.push_back(&q, i)
    }

    queue.pop_front(&q)
    queue.pop_front(&q)
    queue.pop_front(&q)
    queue.pop_back(&q)

    {
        iter := Queue_Iterator(int){&q, 0}
        for number, i in queue_iterate(&iter) {
            fmt.println(number, i)
        }

    }

    {
        q = {}
        iter := Queue_Iterator(int){&q, 0}
        for number, i in queue_iterate(&iter) {
            fmt.println(number, i)
        }
    }
}

// ----------------------------------------------------------------------------- PRIMITIVES

Message :: struct {
    port:  string,
    datum: Data, // TODO(z64): generic
}

Data :: int

// fifo.py

Queue      :: queue.Queue(Message)
fifo_push  :: queue.push_back
fifo_pop   :: queue.pop_front_safe
fifo_clear :: queue.clear

// eh.py

Eh :: struct {
    name:   string,
    input:  Queue,
    output: Queue,
}

eh_enqueue_input :: proc(eh: ^Eh, message: Message) {
    fifo_push(&eh.input, message)
}

eh_enqueue_output :: proc(eh: ^Eh, message: Message) {
    fifo_push(&eh.output, message)
}

eh_deqeue_input :: proc(eh: ^Eh) -> (message: Message, ok: bool) {
    return fifo_pop(&eh.input)
}

eh_deqeue_output :: proc(eh: ^Eh) -> (message: Message, ok: bool) {
    return fifo_pop(&eh.output)
}

eh_clear_output :: proc(eh: ^Eh) {
    fifo_clear(&eh.output)
}

eh_output_list :: proc(eh: ^Eh, allocator := context.allocator) -> []Message {
    list := make([]Message, eh.output.len)

    iter := make_queue_iterator(&eh.output)
    for msg, i in queue_iterate(&iter) {
        list[i] = msg
    }

    return list
}

eh_input_empty :: proc(eh: ^Eh) -> bool {
    return eh.input.len == 0
}

eh_output_empty :: proc(eh: ^Eh) -> bool {
    return eh.output.len == 0
}

// connection.py

Sender :: struct {
    component: ^Eh,
    port:      string,
}

Receiver :: struct {
    queue: ^queue.Queue(Message),
    port:  string,
}

Connector :: struct {
    direction: Direction,
    sender:    Sender,
    receiver:  Receiver,
}

Direction :: enum {
    Down,
    Up,
    Across,
    Through,
}

connector_deposit :: proc(c: Connector, datum: Data) {
    fifo_push(c.receiver.queue, Message{c.receiver.port, datum})
}

sender :: proc(eh: ^Eh, port: string) -> Sender {
    return {eh, port}
}

sender_eq :: proc(s1, s2: Sender) -> bool {
    // NOTE(z64): this uses pointer equality - is that enough? i think so..
    return s1.component == s2.component && s1.port == s2.port
}

receiver :: proc(component: Component, port: string) -> Receiver {
    eh := component_as_eh(component)
    queue := transmute(^queue.Queue(Message))&eh.input
    return {queue, port}
}

// ----------------------------------------------------------------------------- COMPONENTS

// leaf.py

Leaf_Handle_Proc :: #type proc(leaf: ^Leaf, message: Message)

Leaf :: struct {
    using eh: Eh,
    handle: Leaf_Handle_Proc,
}

// container.py

Container :: struct {
    using eh:    Eh,
    children:    []Component,
    connections: []Connector,
}

Component :: union #shared_nil {
    ^Leaf,
    ^Container,
}

send :: proc(eh: ^Eh, port: string, datum: Data) {
    eh_enqueue_output(eh, {port, datum})
}

container_handle :: proc(eh: ^Eh, message: Message) {
    container := (cast(^Container)eh)^
    container_route_downwards(container, message.port, message.datum)
    for container_any_child_ready(container) {
        container_dispatch_children(container)
    }
}

container_dispatch_children :: proc(container: Container) {
    children := container.children
    for child in &children {
        eh := component_as_eh(child)
        if container_child_is_ready(eh) {
            msg, ok := eh_deqeue_input(eh)
            switch component in child {
            case ^Leaf:      component.handle(component, msg)
            case ^Container: container_handle(eh, msg)
            }
            container_route_child_output_and_clear(container, eh)
        }
    }
}

container_route_child_output_and_clear :: proc(container: Container, child: ^Eh) {
    outputs := eh_output_list(child)
    defer delete(outputs)
    for output_message in outputs {
        container_route_child_output(container, child, output_message.port, output_message.datum)
    }
    eh_clear_output(child)
}

container_route :: proc(container: Container, from: ^Eh, port: string, datum: Data) {
    from_sender := Sender{from, port}
    for connector in container.connections {
        if sender_eq(from_sender, connector.sender) {
            connector_deposit(connector, datum)
        }
    }
}

container_route_downwards :: proc(container: Container, port: string, datum: Data) {
    container_route(container, nil, port, datum)
}

container_route_child_output :: proc(container: Container, from: ^Eh, port: string, datum: Data) {
    container_route(container, from, port, datum)
}

container_child_is_ready :: proc(eh: ^Eh) -> bool {
    // NOTE(z64): this is correct per py0d, though the semantics are confusing
    // to me... i think the intention might be an "edge" trigger of input
    // loaded, and output empty....?
    return !eh_output_empty(eh) || !eh_input_empty(eh)
}

component_as_eh :: proc(c: Component) -> ^Eh {
    Raw_Component_Union :: struct{
        eh:  ^Eh,
        tag: int,
    }
    raw := transmute(Raw_Component_Union)c
    return raw.eh
}

container_any_child_ready :: proc(container: Container) -> (ready: bool) {
    for c in container.children {
        eh := component_as_eh(c)
        if container_child_is_ready(eh) {
            return true
        }
    }
    return false
}

// ----------------------------------------------------------------------------- TESTS


main :: proc() {
    // Constant version of the leaf definiton, to save repeating in examples...
    Echo :: Leaf {
        handle = proc(leaf: ^Leaf, message: Message) {
            send(leaf, "stdout", message.datum)
        },
    }

    fmt.println("--- WrappedEcho")
    {
        echo := new_clone(Echo)
        echo.name = "0"

        container: Container

        container.children = {
            echo,
        }

        container.connections = {
            Connector{.Down, {nil, "stdin"}, {&echo.input, "stdin"}},
            Connector{.Up, {echo, "stdout"}, {&container.output, "stdout"}},
        }

        container_handle(&container, {"stdin", 1})
        fmt.println(eh_output_list(&container))
    }

    fmt.println("--- WrappedEcho2")
    {
        echo1 := new_clone(Echo)
        echo1.name = "10"
        echo2 := new_clone(Echo)
        echo2.name = "11"

        container: Container

        container.children = {
            echo1,
            echo2,
        }

        container.connections = {
            Connector{.Down, {nil, "stdin"}, {&echo1.input, "stdin"}},
            Connector{.Across, {nil, "stdin"}, {&echo2.input, "stdin"}},
            Connector{.Up, {echo2, "stdout"}, {&container.output, "stdout"}},
        }

        container_handle(&container, {"stdin", 2})
        fmt.println(eh_output_list(&container))
    }

    fmt.println("--- WrappedWrappedEcho")
    {
        echo: Container
        echo.name = "Echo"
        {
            echo0 := new_clone(Echo)
            echo0.name = "0"

            echo.children = {
                echo0,
            }

            echo.connections = {
                Connector{.Down, {nil, "stdin"}, {&echo0.input, "stdin"}},
                Connector{.Up, {echo0, "stdout"}, {&echo.output, "stdout"}},
            }
        }

        top: Container
        top.name = "Top"
        {
            top.children = {
                &echo,
            }

            top.connections = {
                Connector{.Down, {nil, "stdin"}, {&echo.input, "stdin"}},
                Connector{.Up, {&echo, "stdout"}, {&top.output, "stdout"}},
            }
        }
        container_handle(&top, {"stdin", 3})
        fmt.println(eh_output_list(&top))
    }

    fmt.println("--- ParEcho")
    {
        echo0 := new_clone(Echo)
        echo0.name = "20"
        echo1 := new_clone(Echo)
        echo1.name = "21"

        par_echo: Container

        par_echo.children = {
            echo0,
            echo1,
        }

        par_echo.connections = {
            {.Down, {nil, "stdin"}, {&echo0.input, "stdin"}},
            {.Down, {nil, "stdin"}, {&echo1.input, "stdin"}},
            {.Up, {echo0, "stdout"}, {&par_echo.output, "stdout"}},
            {.Up, {echo1, "stdout"}, {&par_echo.output, "stdout"}},
        }

        container_handle(&par_echo, {"stdin", 4})
        fmt.println(eh_output_list(&par_echo))
    }

    fmt.println("--- PWEcho")
    {
        // NOTE(z64): i don't have a "deep clone" yet, so just setting two up manually... :)
        wrapped_echo0: Container
        {
            echo0 := new_clone(Echo)
            echo0.name = "0"

            wrapped_echo0.children = {
                echo0,
            }

            wrapped_echo0.connections = {
                {.Down, {nil, "stdin"}, {&echo0.input, "stdin"}},
                {.Up, {echo0, "stdout"}, {&wrapped_echo0.output, "stdout"}},
            }
        }

        wrapped_echo1: Container
        {
            echo0 := new_clone(Echo)
            echo0.name = "0"

            wrapped_echo1.children = {
                echo0,
            }

            wrapped_echo1.connections = {
                {.Down, {nil, "stdin"}, {&echo0.input, "stdin"}},
                {.Up, {echo0, "stdout"}, {&wrapped_echo1.output, "stdout"}},
            }
        }

        par_echo: Container

        par_echo.children = {
            &wrapped_echo0,
            &wrapped_echo1,
        }

        par_echo.connections = {
            {.Down, {nil, "stdin"}, {&wrapped_echo0.input, "stdin"}},
            {.Down, {nil, "stdin"}, {&wrapped_echo1.input, "stdin"}},
            {.Up, {&wrapped_echo0, "stdout"}, {&par_echo.output, "stdout"}},
            {.Up, {&wrapped_echo1, "stdout"}, {&par_echo.output, "stdout"}},
        }

        container_handle(&par_echo, {"stdin", 4})
        fmt.println(eh_output_list(&par_echo))
    }

    fmt.println("--- FeedbackTest")
    {
        a := new_clone(Leaf {
            eh = {
                name = "A",
            },
            handle = proc(leaf: ^Leaf, message: Message) {
                send(leaf, "stdout", 100)
                send(leaf, "stdout", 200)
            },
        })

        b := new_clone(Leaf {
            eh = {
                name = "B",
            },
            handle = proc(leaf: ^Leaf, message: Message) {
                switch message.port {
                case "stdin":
                    send(leaf, "stdout", message.datum)
                    send(leaf, "feedback", 300)
                case "fback":
                    send(leaf, "stdout", message.datum)
                }
            },
        })

        top: Container

        top.children = {
            a,
            b,
        }

        top.connections = {
            {.Down, {nil, "stdin"}, {&a.input, "stdin"}},
            {.Across, {a, "stdout"}, {&b.input, "stdin"}},
            {.Across, {b, "feedback"}, {&b.input, "fback"}},
            {.Up, {b, "stdout"}, {&top.output, "stdout"}},
        }

        container_handle(&top, {"stdin", 5})
        fmt.println(eh_output_list(&top))
    }
}
