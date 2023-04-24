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

collect_children :: proc(cells: []dg.Cell) -> []Elem_Reference {
    children := make([dynamic]Elem_Reference)

    for cell in cells {
        if cell.type == .Rect && .Container in cell.flags {
            ref := Elem_Reference{cell.value, cell.id}
            append(&children, ref)
        }
    }

    return children[:]
}

collect_up_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Up

        target_rhombus := cells[cell.target]
        if target_rhombus.type != .Rhombus do continue

        // NOTE(z64): right now, i allow this to be any shape... might be ok?
        source_cell := cells[cell.source]

        decl.source_port = source_cell.value
        decl.target_port = target_rhombus.value

        parent_rect := cells[source_cell.parent]
        if !(parent_rect.type == .Rect && .Container in parent_rect.flags) {
            continue
        }

        decl.source = {parent_rect.value, parent_rect.id}

        append(decls, decl)
    }
}

collect_across_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Across

        source_port := cells[cell.source]
        target_port := cells[cell.target]

        decl.source_port = source_port.value
        decl.target_port = target_port.value

        source_rect := cells[source_port.parent]
        target_rect := cells[target_port.parent]
        if !(source_rect.type == .Rect && .Container in source_rect.flags) {
            continue
        }
        if !(target_rect.type == .Rect && .Container in target_rect.flags) {
            continue
        }

        decl.source = {source_rect.value, source_rect.id}
        decl.target = {target_rect.value, target_rect.id}

        append(decls, decl)
    }
}

collect_down_decls :: proc(cells: []dg.Cell, decls: ^[dynamic]Connect_Decl) {
    for cell in cells {
        if cell.type != .Arrow do continue

        decl: Connect_Decl
        decl.dir = .Down

        source_rhombus := cells[cell.source]
        if source_rhombus.type != .Rhombus do continue

        // NOTE(z64): right now, i allow this to be any shape... might be ok?
        target_cell := cells[cell.target]

        decl.source_port = source_rhombus.value
        decl.target_port = target_cell.value

        parent_rect := cells[target_cell.parent]
        if parent_rect.type != .Rect && .Container in parent_rect.flags {
            continue
        }

        decl.target = {parent_rect.value, parent_rect.id}

        append(decls, decl)
    }
}

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
