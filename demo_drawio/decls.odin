package demo_drawio

import dg "../diagram"
import zd "../0d"

Container_Decl :: struct {
    name:        string,
    children:    []Elem_Reference,
    connections: []Connect_Decl,
}

Connect_Decl :: struct {
    dir:         zd.Direction,
    source:      Elem_Reference,
    source_port: string,
    target:      Elem_Reference,
    target_port: string,
}

Elem_Reference :: struct {
    name: string,
    id:   int,
}

container_decl_from_diagram :: proc(page: dg.Page) -> Container_Decl {
    decl: Container_Decl
    decl.name = page.name

    decl.children = collect_children(page.cells)

    connections := make([dynamic]Connect_Decl)
    collect_down_decls(page.cells, &connections)
    collect_across_decls(page.cells, &connections)
    collect_up_decls(page.cells, &connections)
    collect_through_decls(page.cells, &connections)
    decl.connections = connections[:]

    return decl
}

// Children are list of named rects on the page
collect_children :: proc(cells: []dg.Cell) -> []Elem_Reference {
    children := make([dynamic]Elem_Reference)

    for cell in cells {
        if cell.type != .Rect || cell.value == "" {
            continue
        }
        ref := Elem_Reference{cell.value, cell.id}
        append(&children, ref)
    }

    return children[:]
}

// Up connentions are from rect, to ellipse, to rhombus
//
// <----------o--->
//   S   T  S   T
// [] --> () --> <>
collect_up_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Up

        source_port_ellipse := cells[cell.source]
        if source_port_ellipse.type != .Ellipse do continue

        target_rhombus := cells[cell.target]
        if target_rhombus.type != .Rhombus do continue

        decl.source_port = source_port_ellipse.value
        decl.target_port = target_rhombus.value

        source_arrow: dg.Cell
        found := false

        for c in cells {
            if c.type == .Arrow && c.target == source_port_ellipse.id {
                source_arrow = c
                found = true
                break
            }
        }
        if !found do break

        source := cells[source_arrow.source]
        if source.type != .Rect do continue

        decl.source = {source.value, source.id}

        append(decls, decl)
    }
}

// Across connections are from rect, to ellipse, to ellipse, to rect
//
// <----------o---------->
//   S   T  S   T  S   T
// [] --> () --> () --> []
collect_across_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Across

        source_ellipse := cells[cell.source]
        target_ellipse := cells[cell.target]
        if source_ellipse.type != .Ellipse do continue
        if target_ellipse.type != .Ellipse do continue

        decl.source_port = source_ellipse.value
        decl.target_port = target_ellipse.value

        source_arrow: dg.Cell
        target_arrow: dg.Cell

        found := false
        for c in cells {
            if c.type == .Arrow && c.target == source_ellipse.id {
                source_arrow = c
                found = true
                break
            }
        }
        if !found do continue

        found = false
        for c in cells {
            if c.type == .Arrow && c.source == target_ellipse.id {
                target_arrow = c
                found = true
                break
            }
        }
        if !found do continue

        source := cells[source_arrow.source]
        target := cells[target_arrow.target]
        if source.type != .Rect do continue
        if target.type != .Rect do continue

        decl.source = {source.value, source.id}
        decl.target = {target.value, target.id}

        append(decls, decl)
    }
}

// Down connections are from rhombus, to ellipse, to rect
//
// <---o---------->
//   S   T  S   T
// <> --> () --> []
collect_down_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Down

        source_rhombus := cells[cell.source]
        if source_rhombus.type != .Rhombus do continue

        target_ellipse := cells[cell.target]
        if target_ellipse.type != .Ellipse do continue

        decl.source_port = source_rhombus.value
        decl.target_port = target_ellipse.value

        target_arrow: dg.Cell
        found := false

        for c in cells {
            if c.type == .Arrow && c.source == target_ellipse.id {
                target_arrow = c
                found = true
                break
            }
        }
        if !found do break

        target := cells[target_arrow.target]
        if target.type != .Rect do continue

        decl.target = {target.value, target.id}

        append(decls, decl)
    }
}

// Through connections are between two rhombi
//
//   S          T
// <> -----o---> <>
collect_through_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Through

        source_rhombus := cells[cell.source]
        target_rhombus := cells[cell.target]
        if source_rhombus.type != .Rhombus do continue
        if target_rhombus.type != .Rhombus do continue

        decl.source_port = source_rhombus.value
        decl.target_port = target_rhombus.value

        append(decls, decl)
    }
}
