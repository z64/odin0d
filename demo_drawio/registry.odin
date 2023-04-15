package demo_drawio

import dg "../diagram"
import zd "../0d"

Component_Registry :: map[string]^zd.Eh

register_leaves :: proc(r: ^Component_Registry, leaves: []^zd.Eh) {
    for leaf in leaves {
        r[leaf.name] = leaf
    }
}

register_containers :: proc(r: ^Component_Registry, path: string) {
    diagram_pages, ok := dg.read_from_xml_file(path)
    assert(ok)

    decls := make([dynamic]Container_Decl)
    for page in diagram_pages {
        decl := container_decl_from_diagram(page)
        append(&decls, decl)
    }

    // first pass to register empty containers
    for d in decls {
        r[d.name] = zd.make_container(d.name)
    }

    // second pass to establish children and connections
    for d in decls {
        component := r[d.name]

        children := make([dynamic]^zd.Eh)
        for child_name in d.children {
            child_component, ok := r[child_name]
            if !ok {
                // Missing child definition (leaf or container)
            }
            append(&children, child_component)
        }
        component.children = children[:]

        connectors := make([dynamic]zd.Connector)
        for c in d.connections {
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

                target_component, target_ok = r[c.target]
                connector.receiver = {
                    &target_component.input,
                    c.target_port,
                }
            case .Across:
                source_component, source_ok = r[c.source]
                target_component, target_ok = r[c.target]

                connector.sender = {
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
                    &target_component.input,
                    c.target_port,
                }
            case .Up:
                source_component, source_ok = r[c.source]
                connector.sender = {
                    source_component,
                    c.source_port,
                }

                connector.receiver = {
                    &component.output,
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
                    &component.output,
                    c.target_port,
                }
                target_ok = true
            }

            if source_ok && target_ok {
                append(&connectors, connector)
            }
        }
        component.connections = connectors[:]
    }
}
