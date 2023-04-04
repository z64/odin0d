package zd

import "core:fmt"
import "core:slice"

main :: proc() {
    fmt.println("--- WrappedEcho")
    {
        top := make_container("Echo", string)

        echo := make_leaf("0",
            proc(eh: ^Eh(string), message: Message(string)) {
                send(eh, "stdout", message.datum)
            },
        )

        top.children = {
            echo,
        }

        top.connections = {
            {.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
            {.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
        }

        top.handler(top, {"stdin", "hello"})
        fmt.println(eh_output_list(top))
    }

    fmt.println("--- WrappedEcho2")
    {
        echo_handler :: proc(eh: ^Eh(string), message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        echo0 := make_leaf("10", echo_handler)
        echo1 := make_leaf("11", echo_handler)

        top := make_container("Top", string)

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
        fmt.println(eh_output_list(top))
    }

    fmt.println("--- WrappedWrappedEcho")
    {
        echo_container := make_container("Echo", string)
        {
            top := echo_container

            echo_handler :: proc(eh: ^Eh(string), message: Message(string)) {
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

        top_container := make_container("Top", string)
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
        fmt.println(eh_output_list(top_container))
    }

    fmt.println("--- ParEcho")
    {
        echo_handler :: proc(eh: ^Eh(string), message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        top := make_container("Top", string)

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
        fmt.println(eh_output_list(top))
    }

    fmt.println("--- PWEcho")
    {
        echo_handler :: proc(eh: ^Eh(string), message: Message(string)) {
            send(eh, "stdout", message.datum)
        }

        make_echo_container :: proc(name: string) -> ^Eh(string) {
            top := make_container(name, string)

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

        top := make_container("PWEcho", string)

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
        fmt.println(eh_output_list(top))
    }

    fmt.println("--- FeedbackTest")
    {
        a := make_leaf("A",
            proc(eh: ^Eh(string), message: Message(string)) {
                send(eh, "stdout", "v")
                send(eh, "stdout", "w")
            },
        )

        b := make_leaf("B",
            proc(eh: ^Eh(string), message: Message(string)) {
                switch message.port {
                case "stdin":
                    send(eh, "stdout", message.datum)
                    send(eh, "feedback", "z")
                case "fback":
                    send(eh, "stdout", message.datum)
                }
            },
        )

        top := make_container("Top", string)

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
        fmt.println(eh_output_list(top))
    }
}
