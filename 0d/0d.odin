package zd

import "core:container/queue"
import "core:fmt"

// Data for an asyncronous component - effectively, a function with input
// and output queues of messages.
//
// Components can either be a user-supplied function ("leaf"), or a "container"
// that routes messages to child components according to a list of connections
// that serve as a message routing table.
//
// Child components themselves can be leaves or other containers.
//
// `handler` invokes the code that is attached to this component. For leaves, it
// is a wrapper function around `leaf_handler` that will perform a type check
// before calling the user's function. For containers, `handler` is a reference
// to `container_handler`, which will dispatch messages to its children.
//
// `leaf_data` is a pointer to any extra state data that the `leaf_handler`
// function may want whenever it is invoked again.
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

// Message passed to a leaf component.
//
// `port` refers to the name of the incoming port to this component.
// `datum` is the data attached to this message, of type `Datum`.
Message :: struct($Datum: typeid) {
    port:  string,
    datum: Datum,
}

// Internal message type that has the type of `datum` erased. This enables
// messages of various types to flow around the internals of the network.
//
// The message is type-checked and converted into a `Message` before calling
// a leaf function.
Message_Untyped :: struct {
    port:  string,
    datum: any,
}

// Creates a component that acts as a container. It is the same as a `Eh` instance
// whose handler function is `container_handler`.
make_container :: proc(name: string) -> ^Eh {
    eh := new(Eh)
    eh.name = name
    eh.handler = container_handler
    return eh
}

// Creates a new leaf component out of a handler function, and optionally a user
// data parameter that will be passed back to your handler when it is run.
make_leaf :: proc{
    make_leaf_simple,
    make_leaf_with_data,
}

// Creates a new leaf component out of a handler function.
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

// Creates a new leaf component out of a handler function, and a data parameter
// that will be passed back to your handler when called.
//
// NOTE(z64): currently, be aware that if there are multiple instances of your
// leaf component in a container, they will all be passed the same data
// parameter.
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

// Sends a message on the given `port` with `data`, placing it on the output
// of the given component.
send :: proc(eh: ^Eh, port: string, data: $Data) {
    data_copy := new_clone(data)

    msg := Message_Untyped {
        port  = port,
        datum = {data_copy, typeid_of(Data)},
    }

    fifo_push(&eh.output, msg)
}

// Returns a list of all output messages on a container.
// For testing / debugging purposes.
output_list :: proc(eh: ^Eh, allocator := context.allocator) -> []Message_Untyped {
    list := make([]Message_Untyped, eh.output.len)

    iter := make_fifo_iterator(&eh.output)
    for msg, i in fifo_iterate(&iter) {
        list[i] = msg
    }

    return list
}

// The default handler for container components.
container_handler :: proc(eh: ^Eh, message: Message_Untyped) {
    route(eh, nil, message)
    for any_child_ready(eh) {
        dispatch_children(eh)
    }
}

// Frees the given container and associated data.
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

// Wrapper for corelib `queue.Queue` with FIFO semantics.
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

// Routing connection for a container component. The `direction` field has
// no affect on the default message routing system - it is there for debugging
// purposes, or for reading by other tools.
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

// `Sender` is used to "pattern match" which `Receiver` a message should go to,
// based on component ID (pointer) and port name.
Sender :: struct {
    component: ^Eh,
    port:      string,
}

// `Receiver` is a handle to a destination queue, and a `port` name to assign
// to incoming messages to this queue.
Receiver :: struct {
    queue: ^FIFO,
    port:  string,
}

// Checks if two senders match, by pointer equality and port name matching.
sender_eq :: proc(s1, s2: Sender) -> bool {
    return s1.component == s2.component && s1.port == s2.port
}

// Delivers the given message to the receiver of this connector.
deposit :: proc(c: Connector, message: Message_Untyped) {
    message := message
    message.port = c.receiver.port
    fifo_push(c.receiver.queue, message)
}

// For all children that are ready to process messages, consumes a message
// from their input queue, calls their handler, and then routes any output
// messages they produced.
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

// Routes a single message to all matching destinations, according to
// the container's connection network.
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
