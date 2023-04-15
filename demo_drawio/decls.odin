package demo_drawio

import dg "../diagram"
import zd "../0d"

Container_Decl :: struct {
    name:        string,
    children:    []string,
    connections: []Connect_Decl,
}

Connect_Decl :: struct {
    dir:         zd.Direction,
    source:      string,
    source_port: string,
    target:      string,
    target_port: string,
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

// Children are the unique list of rects on the page
collect_children :: proc(cells: []dg.Cell) -> []string {
    children := make([dynamic]string)

    for cell in cells {
        if cell.type != .Rect || cell.value == "" {
            continue
        }

        found := false
        for c in children {
            if c == cell.value {
                found = true
                break
            }
        }

        if !found {
            append(&children, cell.value)
        }
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

        target_rhombus_cell := cells[cell.target]
        if target_rhombus_cell.type != .Rhombus do continue

        decl.source_port = source_port_ellipse.value
        decl.target_port = target_rhombus_cell.value

        source_cell_arrow: dg.Cell
        found := false

        for c in cells {
            if c.type == .Arrow && c.target == source_port_ellipse.id {
                source_cell_arrow = c
                found = true
                break
            }
        }
        if !found do break

        source_cell := cells[source_cell_arrow.source]
        if source_cell.type != .Rect do continue

        decl.source = source_cell.value

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

        source_ellipse_cell := cells[cell.source]
        target_ellipse_cell := cells[cell.target]
        if source_ellipse_cell.type != .Ellipse do continue
        if target_ellipse_cell.type != .Ellipse do continue

        decl.source_port = source_ellipse_cell.value
        decl.target_port = target_ellipse_cell.value

        source_cell_arrow: dg.Cell
        target_cell_arrow: dg.Cell

        found := false
        for c in cells {
            if c.type == .Arrow && c.target == source_ellipse_cell.id {
                source_cell_arrow = c
                found = true
                break
            }
        }
        if !found do continue

        found = false
        for c in cells {
            if c.type == .Arrow && c.source == target_ellipse_cell.id {
                target_cell_arrow = c
                found = true
                break
            }
        }
        if !found do continue

        source_cell := cells[source_cell_arrow.source]
        target_cell := cells[target_cell_arrow.target]
        if source_cell.type != .Rect do continue
        if target_cell.type != .Rect do continue

        decl.source = source_cell.value
        decl.target = target_cell.value

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

        source_rhombus_cell := cells[cell.source]
        if source_rhombus_cell.type != .Rhombus do continue

        target_cell_ellipse := cells[cell.target]
        if target_cell_ellipse.type != .Ellipse do continue

        decl.source_port = source_rhombus_cell.value
        decl.target_port = target_cell_ellipse.value

        target_cell_arrow: dg.Cell
        found := false

        for c in cells {
            if c.type == .Arrow && c.source == target_cell_ellipse.id {
                target_cell_arrow = c
                found = true
                break
            }
        }
        if !found do break

        target_cell := cells[target_cell_arrow.target]
        if target_cell.type != .Rect do continue

        decl.target = target_cell.value

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

        source_rhombus_cell := cells[cell.source]
        target_rhombus_cell := cells[cell.target]
        if source_rhombus_cell.type != .Rhombus do continue
        if target_rhombus_cell.type != .Rhombus do continue

        decl.source_port = source_rhombus_cell.value
        decl.target_port = target_rhombus_cell.value

        append(decls, decl)
    }
}

