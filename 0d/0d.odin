package zd

import "core:container/queue"
import "core:fmt"

Eh :: struct {
    name:         string,
    input:        FIFO,
    output:       FIFO,
    children:     []^Eh,
    connections:  []Connector,
    handler:      #type proc(eh: ^Eh, message: Message_Untyped),
    leaf_handler: rawptr, //#type proc(eh: ^Eh, message: Message($Datum)),
    leaf_data:    rawptr, //#type proc(eh: ^Eh, message: Message($Datum), data: ^$Data),
}

Message :: struct($Datum: typeid) {
    port:  string,
    datum: Datum,
}

Message_Untyped :: struct {
    port:  string,
    datum: any,
}

make_container :: proc(name: string) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = container_handler
    return eh
}

make_leaf :: proc{
    make_leaf_simple,
    make_leaf_with_data,
}

make_leaf_simple :: proc(name: string, handler: proc(^Eh, Message($Datum))) -> ^Eh {
    leaf_handler :: proc(eh: ^Eh, message: Message_Untyped) {
        datum, ok := message.datum.(Datum)
        fmt.assertf(ok, "Component %s got message with type %v, expected %v", eh.name, message.datum.id, typeid_of(Datum))

        handler := (proc(^Eh, Message(Datum)))(eh.leaf_handler)
        handler(eh, {message.port, datum})
    }

    eh := new(Eh)
    eh.name = name
    eh.handler = leaf_handler
    eh.leaf_handler = rawptr(handler)
    return eh
}

make_leaf_with_data :: proc(name: string, data: ^$Data, handler: proc(^Eh, Message($Datum), ^Data)) -> ^Eh {
    leaf_handler :: proc(eh: ^Eh, message: Message_Untyped) {
        datum, ok := message.datum.(Datum)
        fmt.assertf(ok, "Component %s got message with type %v, expected %v", eh.name, message.datum.id, typeid_of(Datum))

        handler := (proc(^Eh, Message(Datum), ^Data))(eh.leaf_handler)
        data := (^Data)(eh.leaf_data)

        handler(eh, {message.port, datum}, data)
    }

    eh := new(Eh)
    eh.name = name
    eh.handler = leaf_handler
    eh.leaf_handler = rawptr(handler)
    eh.leaf_data = data
    return eh
}

send :: proc(eh: ^Eh, port: string, datum: $Datum) {
    datum_copy := new_clone(datum)

    msg := Message_Untyped {
        port  = port,
        datum = {datum_copy, typeid_of(Datum)},
    }

    fifo_push(&eh.output, msg)
}

output_list :: proc(eh: ^Eh, allocator := context.allocator) -> []Message_Untyped {
    list := make([]Message_Untyped, eh.output.len)

    iter := make_fifo_iterator(&eh.output)
    for msg, i in fifo_iterate(&iter) {
        list[i] = msg
    }

    return list
}

container_handler :: proc(eh: ^Eh, message: Message_Untyped) {
    route(eh, nil, message)
    for any_child_ready(eh) {
        dispatch_children(eh)
    }
}

destroy_container :: proc(eh: ^Eh) {
    drain_fifo :: proc(fifo: ^FIFO) {
        for fifo.len > 0 {
            msg, _ := fifo_pop(fifo)
            free(msg.datum.data)
        }
    }
    drain_fifo(&eh.input)
    drain_fifo(&eh.output)
    free(eh)
}

FIFO       :: queue.Queue(Message_Untyped)
fifo_push  :: queue.push_back
fifo_pop   :: queue.pop_front_safe

fifo_is_empty :: proc(fifo: FIFO) -> bool {
    return fifo.len == 0
}

FIFO_Iterator :: struct {
    q:   ^FIFO,
    idx: int,
}

make_fifo_iterator :: proc(q: ^FIFO) -> FIFO_Iterator {
    return {q, 0}
}

fifo_iterate :: proc(iter: ^FIFO_Iterator) -> (item: Message_Untyped, idx: int, ok: bool) {
    i := (uint(iter.idx)+iter.q.offset) % len(iter.q.data)
    if i < iter.q.len {
        ok = true
        idx = iter.idx
        iter.idx += 1
        #no_bounds_check item = iter.q.data[i]
    }
    return
}

Connector :: struct {
    direction: Direction,
    sender:    Sender,
    receiver:  Receiver,
}

Direction :: enum {
    Down,
    Across,
    Up,
    Through,
}

Sender :: struct {
    component: ^Eh,
    port:      string,
}

Receiver :: struct {
    queue: ^FIFO,
    port:  string,
}

sender_eq :: proc(s1, s2: Sender) -> bool {
    return s1.component == s2.component && s1.port == s2.port
}

deposit :: proc(c: Connector, message: Message_Untyped) {
    message := message
    message.port = c.receiver.port
    fifo_push(c.receiver.queue, message)
}

dispatch_children :: proc(container: ^Eh) {
    route_child_outputs :: proc(container: ^Eh, child: ^Eh) {
        for child.output.len > 0 {
            msg, _ := fifo_pop(&child.output)
            route(container, child, msg)
        }
    }

    for child in &container.children {
        if child_is_ready(child) {
            msg, ok := fifo_pop(&child.input)
            assert(ok, "child was ready, but no message in input queue")
            child.handler(child, msg)
            route_child_outputs(container, child)
        }
    }
}

import "core:runtime"

route :: proc(container: ^Eh, from: ^Eh, message: Message_Untyped) {
    from_sender := Sender{from, message.port}
    sent := false

    for connector in container.connections {
        if sender_eq(from_sender, connector.sender) {
            deposit(connector, message)
            sent = true
        }
    }

    if !sent {
        free(message.datum.data)
    }
}

any_child_ready :: proc(container: ^Eh) -> (ready: bool) {
    for child in container.children {
        if child_is_ready(child) {
            return true
        }
    }
    return false
}

child_is_ready :: proc(eh: ^Eh) -> bool {
    return !fifo_is_empty(eh.output) || !fifo_is_empty(eh.input)
}
