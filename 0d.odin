package zd

import "core:container/queue"

Message :: struct($Datum: typeid) {
    port:  string,
    datum: Datum,
}

Eh :: struct($Datum: typeid) {
    name:        string,
    input:       FIFO(Datum),
    output:      FIFO(Datum),
    children:    []^Eh(Datum),
    connections: []Connector(Datum),
    handler:     #type proc(eh: ^Eh(Datum), message: Message(Datum)),
}

eh_enqueue_input :: proc(eh: ^Eh($Datum), message: Message(Datum)) {
    fifo_push(&eh.input, message)
}

eh_enqueue_output :: proc(eh: ^Eh($Datum), message: Message(Datum)) {
    fifo_push(&eh.output, message)
}

eh_deqeue_input :: proc(eh: ^Eh($Datum)) -> (message: Message(Datum), ok: bool) {
    return fifo_pop(&eh.input)
}

eh_deqeue_output :: proc(eh: ^Eh($Datum)) -> (message: Message(Datum), ok: bool) {
    return fifo_pop(&eh.output)
}

eh_clear_output :: proc(eh: ^Eh($Datum)) {
    fifo_clear(&eh.output)
}

eh_output_list :: proc(eh: ^Eh($Datum), allocator := context.allocator) -> []Message(Datum) {
    list := make([]Message(Datum), eh.output.queue.len)

    iter := make_queue_iterator(&eh.output.queue)
    for msg, i in queue_iterate(&iter) {
        list[i] = msg
    }

    return list
}

eh_input_empty :: proc(eh: ^Eh($Datum)) -> bool {
    return fifo_is_empty(&eh.input)
}

eh_output_empty :: proc(eh: ^Eh($Datum)) -> bool {
    return fifo_is_empty(&eh.output)
}

send :: proc(eh: ^Eh($Datum), port: string, datum: Datum) {
    eh_enqueue_output(eh, Message(Datum){port, datum})
}

make_container :: proc(name: string, $Datum: typeid) -> ^Eh(Datum) {
    container_handler :: proc(eh: ^Eh(Datum), message: Message(Datum)) {
        container_route(eh, nil, message.port, message.datum)
        for container_any_child_ready(eh) {
            container_dispatch_children(eh)
        }
    }
    eh := new(Eh(Datum))
    eh.handler = container_handler
    return eh
}

make_leaf :: proc(name: string, handler: proc(^Eh($Datum), Message(Datum))) -> ^Eh(Datum) {
    eh := new(Eh(Datum))
    eh.handler = handler
    return eh
}

FIFO :: struct($Datum: typeid) {
    queue: queue.Queue(Message(Datum)),
}

fifo_push :: proc(fifo: ^FIFO($Datum), message: Message(Datum)) {
    queue.push_back(&fifo.queue, message)
}

fifo_pop :: proc(fifo: ^FIFO($Datum)) -> (data: Message(Datum), ok: bool) {
    return queue.pop_front_safe(&fifo.queue)
}

fifo_clear :: proc(fifo: ^FIFO($Datum)) {
    queue.clear(&fifo.queue)
}

fifo_is_empty :: proc(fifo: ^FIFO($Datum)) -> bool {
    return fifo.queue.len == 0
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

Connector :: struct($Datum: typeid) {
    direction: Direction,
    sender:    Sender(Datum),
    receiver:  Receiver(Datum),
}

Direction :: enum {
    Down,
    Up,
    Across,
    Through,
}

Sender :: struct($Datum: typeid) {
    component: ^Eh(Datum),
    port:      string,
}

Receiver :: struct($Datum: typeid) {
    queue: ^FIFO(Datum),
    port:  string,
}

sender_eq :: proc(s1, s2: Sender($Datum)) -> bool {
    return s1.component == s2.component && s1.port == s2.port
}

connector_deposit :: proc(c: Connector($Datum), datum: Datum) {
    fifo_push(c.receiver.queue, Message(Datum){c.receiver.port, datum})
}

container_dispatch_children :: proc(container: ^Eh($Datum)) {
    route_child_outputs :: proc(container: ^Eh($Datum), child: ^Eh(Datum)) {
        outputs := eh_output_list(child)
        defer delete(outputs)

        for output_message in outputs {
            container_route(container, child, output_message.port, output_message.datum)
        }
        eh_clear_output(child)
    }

    for child in &container.children {
        if container_child_is_ready(child) {
            msg, ok := eh_deqeue_input(child)
            assert(ok, "child was ready, but no message in input queue")
            child.handler(child, msg)
            route_child_outputs(container, child)
        }
    }
}

container_route :: proc(container: ^Eh($Datum), from: ^Eh(Datum), port: string, datum: Datum) {
    from_sender := Sender(Datum){from, port}
    for connector in container.connections {
        if sender_eq(from_sender, connector.sender) {
            connector_deposit(connector, datum)
        }
    }
}

container_any_child_ready :: proc(container: ^Eh($Datum)) -> (ready: bool) {
    for child in container.children {
        if container_child_is_ready(child) {
            return true
        }
    }
    return false
}

container_child_is_ready :: proc(eh: ^Eh($Datum)) -> bool {
    return !eh_output_empty(eh) || !eh_input_empty(eh)
}
