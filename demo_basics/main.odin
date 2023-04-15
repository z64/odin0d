package demo_basics

import "core:fmt"
import "core:slice"
import "core:strings"
import "core:encoding/xml"
import "core:os"

import dg "../diagram"
import zd "../0d"

Eh             :: zd.Eh
Message        :: zd.Message
make_container :: zd.make_container
make_leaf      :: zd.make_leaf
send           :: zd.send
output_list    :: zd.output_list

main :: proc() {
    fmt.println("*** Handmade Visibility Jam ***")

    fmt.println("--- WrappedEcho2")
    {
        echo_handler :: proc(eh: ^Eh, message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        echo0 := make_leaf("10", echo_handler)
        echo1 := make_leaf("11", echo_handler)

        top := make_container("Top")

        top.children = {
            echo0,
            echo1,
        }

        top.connections = {
            {.Down,   {nil, "stdin"},              {&top.children[0].input, "stdin"}},
            {.Across, {top.children[0], "stdout"}, {&top.children[1].input, "stdin"}},
            {.Up,     {top.children[1], "stdout"}, {&top.output, "stdout"}},
        }

        top.handler(top, {"stdin", "hello"})
        print_output_list(output_list(top))
    }

    fmt.println("--- WrappedWrappedEcho")
    {
        echo_container := make_container("Echo")
        {
            top := echo_container

            echo_handler :: proc(eh: ^Eh, message: Message(string)) {
                send(eh, "stdout", message.datum)
            }

            top.children = {
                make_leaf("0", echo_handler),
            }

            top.connections = {
                {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
                {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
            }
        }

        top_container := make_container("Top")
        {
            top := top_container

            top.children = {
                echo_container,
            }

            top.connections = {
                {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
                {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
            }
        }

        top_container.handler(top_container, {"stdin", "hello"})
        print_output_list(output_list(top_container))
    }

    fmt.println("--- ParEcho")
    {
        echo_handler :: proc(eh: ^Eh, message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        top := make_container("Top")

        top.children = {
            make_leaf("20", echo_handler),
            make_leaf("21", echo_handler),
        }

        top.connections = {
            {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
            {.Down, {nil, "stdin"},              {&top.children[1].input, "stdin"}},
            {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
            {.Up,   {top.children[1], "stdout"}, {&top.output, "stdout"}},
        }

        top.handler(top, {"stdin", "hello"})
        print_output_list(output_list(top))
    }

    fmt.println("--- PWEcho")
    {
        echo_handler :: proc(eh: ^Eh, message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        make_echo_container :: proc(name: string) -> ^Eh {
            top := make_container(name)

            top.children = {
                make_leaf("0", echo_handler),
            }

            top.connections = {
                {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
                {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
            }

            // must clone here so that slice literals outlive this setup proc
            top.children = slice.clone(top.children)
            top.connections = slice.clone(top.connections)

            return top
        }

        top := make_container("PWEcho")

        top.children = {
            make_echo_container("30"),
            make_echo_container("31"),
        }

        top.connections = {
            {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
            {.Down, {nil, "stdin"},              {&top.children[1].input, "stdin"}},
            {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
            {.Up,   {top.children[1], "stdout"}, {&top.output, "stdout"}},
        }

        top.handler(top, {"stdin", "hello"})
        print_output_list(output_list(top))
    }

    fmt.println("--- FeedbackTest")
    {
        a := make_leaf("A",
            proc(eh: ^Eh, message: Message(string)) {
                send(eh, "stdout", "v")
                send(eh, "stdout", "w")
            },
        )

        b := make_leaf("B",
            proc(eh: ^Eh, message: Message(string)) {
                switch message.port {
                case "stdin":
                    send(eh, "stdout", message.datum)
                    send(eh, "feedback", "z")
                case "fback":
                    send(eh, "stdout", message.datum)
                }
            },
        )

        top := make_container("Top")

        top.children = {
            a,
            b,
        }

        top.connections = {
            {.Down,   {nil, "stdin"},                {&top.children[0].input, "stdin"}},
            {.Across, {top.children[0], "stdout"},   {&top.children[1].input, "stdin"}},
            {.Across, {top.children[1], "feedback"}, {&top.children[1].input, "fback"}},
            {.Up,     {top.children[1], "stdout"},   {&top.output, "stdout"}},
        }

        top.handler(top, {"stdin", "a"})
        print_output_list(output_list(top))
    }
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
