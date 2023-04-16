package demo_drawio

import "core:fmt"

import dg "../diagram"
import zd "../0d"

Component_Registry :: struct {
    initializers: map[string]Initializer,
}

Container_Initializer :: struct {
    decl: Container_Decl,
}

Leaf_Initializer :: struct {
    name: string,
    init: proc(name: string) -> ^zd.Eh,
}

Initializer :: union {
    Leaf_Initializer,
    Container_Initializer,
}

make_component_registry :: proc(leaves: []Leaf_Initializer, container_xml: string) -> Component_Registry {
    reg: Component_Registry

    for leaf_init in leaves {
        reg.initializers[leaf_init.name] = leaf_init
    }

    pages, ok := dg.read_from_xml_file(container_xml)
    assert(ok, "Failed parsing container XML")

    decls := make([dynamic]Container_Decl)
    defer delete(decls)

    for page in pages {
        decl := container_decl_from_diagram(page)
        append(&decls, decl)
    }

    for decl in decls {
        container_init := Container_Initializer {
            decl = decl,
        }
        reg.initializers[decl.name] = container_init
    }

    return reg
}

get_component_instance :: proc(reg: Component_Registry, name: string) -> (instance: ^zd.Eh, ok: bool) {
    initializer: Initializer
    initializer, ok = reg.initializers[name]
    if ok {
        switch init in initializer {
        case Leaf_Initializer:
            instance = init.init(name)
        case Container_Initializer:
            instance = container_initializer(reg, init.decl)
        }
    }
    return instance, ok
}

container_initializer :: proc(reg: Component_Registry, decl: Container_Decl) -> ^zd.Eh {
    container := zd.make_container(decl.name)

    children := make([dynamic]^zd.Eh)

    // this map is temporarily used to ensure connector pointers into the child array
    // line up to the same instances
    child_id_map := make(map[int]^zd.Eh)
    defer delete(child_id_map)

    // collect children
    {
        for child_decl in decl.children {
            child_instance, ok := get_component_instance(reg, child_decl.name)
            if !ok {
                // TODO(z64): warn
                continue
            }
            append(&children, child_instance)
            child_id_map[child_decl.id] = child_instance
        }
        container.children = children[:]
    }

    // setup connections
    {
        connectors := make([dynamic]zd.Connector)

        for c in decl.connections {
            connector: zd.Connector
            connector.direction = c.dir

            target_component: ^zd.Eh
            target_ok := false

            source_component: ^zd.Eh
            source_ok := false

            switch c.dir {
            case .Down:
                connector.sender = {
                    nil,
                    c.source_port,
                }
                source_ok = true

                target_component, target_ok = child_id_map[c.target.id]
                connector.receiver = {
                    &target_component.input,
                    c.target_port,
                }
            case .Across:
                source_component, source_ok = child_id_map[c.source.id]
                target_component, target_ok = child_id_map[c.target.id]

                connector.sender = {
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
                    &target_component.input,
                    c.target_port,
                }
            case .Up:
                source_component, source_ok = child_id_map[c.source.id]
                connector.sender = {
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
                    &container.output,
                    c.target_port,
                }
                target_ok = true
            case .Through:
                connector.sender = {
                    nil,
                    c.source_port,
                }
                source_ok = true

                connector.receiver = {
                    &container.output,
                    c.target_port,
                }
                target_ok = true
            }

            if source_ok && target_ok {
                append(&connectors, connector)
            }
        }

        container.connections = connectors[:]
    }

    return container
}
