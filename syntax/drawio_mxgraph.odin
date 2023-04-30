package syntax

/*

Routines for taking a draw.io mxgraph XML file and loading them into Page data.
Right now, this is the only supported format. mxGraphs from other drawing
applications may or may not work.

Eventually this API could be normalized to support different sources that can
be coerced into the Page data structure.

*/

import "core:encoding/xml"
import "core:strings"
import "core:slice"

Page :: struct {
    name:  string,
    cells: []Cell,
}

Cell :: struct {
    // raw mxgraph values from the document
    mxgraph_id:     string,
    mxgraph_source: string,
    mxgraph_target: string,
    mxgraph_parent: string,
    value:          string,
    // resolved references as indexes into the `page.cells` slice
    id:             int,
    source:         int,
    target:         int,
    parent:         int,
    // detected properties that are useful for making syntaxes
    flags:          Flag_Set,
    type:           Cell_Type,
}

// Various shapes and element types that are detected.
// The order of this enum is used for sorting `page.cells` later.
Cell_Type :: enum {
    Rhombus,
    Rect,
    Ellipse,
    Arrow,
}

// Flags detected from attributes and styles on the element.
Flag_Value :: enum {
    Vertex,
    Edge,
    Container,
}

Flag_Set :: bit_set[Flag_Value]

page_from_elem :: proc(doc: ^xml.Document, elem: xml.Element) -> (page: Page) {
    // find name
    parent0 := doc.elements[elem.parent]
    parent1 := doc.elements[parent0.parent]
    assert(parent1.ident == "diagram", "Unexpected XML layout (root diagram name)")
    for attr in parent1.attribs {
        if attr.key == "name" {
            page.name = attr.val
            break
        }
    }
    assert(page.name != "", "Page without name")

    // find children
    page.cells = make([]Cell, len(elem.children))
    for child_id, idx in elem.children {
        elem := doc.elements[child_id]
        assert(elem.ident == "mxCell", "Unexpected XML layout (root children)")
        page.cells[idx] = cell_from_elem(elem)
    }

    // sort & assign IDs
    slice.sort_by(page.cells, proc(i, j: Cell) -> bool {
        return i.type < j.type
    })
    for cell, idx in &page.cells {
        cell.id = idx
    }

    // connect source/target references etc.
    for cell in &page.cells {
        for x in page.cells {
            if cell.mxgraph_source == x.mxgraph_id {
                cell.source = x.id
            }
            if cell.mxgraph_target == x.mxgraph_id {
                cell.target = x.id
            }
            if cell.mxgraph_parent == x.mxgraph_id {
                cell.parent = x.id
            }
        }
    }

    return page
}

cell_from_elem :: proc(elem: xml.Element) -> Cell {
    style_kv :: proc(s: string) -> (k, v: string) {
        idx := strings.index(s, "=")
        if idx == -1 {
            k = s
        } else {
            k = s[:idx]
            v = s[idx+1:]
        }
        return k, v
    }

    cell: Cell
        cell.type = .Rect

    for attrib in elem.attribs {
        switch attrib.key {
        case "id":     cell.mxgraph_id = attrib.val
        case "source": cell.mxgraph_source = attrib.val
        case "target": cell.mxgraph_target = attrib.val
        case "parent": cell.mxgraph_parent = attrib.val
        case "value":  cell.value = attrib.val
        case "vertex": incl(&cell.flags, Flag_Value.Vertex)
        case "edge":
            incl(&cell.flags, Flag_Value.Edge)
            cell.type = .Arrow
        case "style":
            iter := attrib.val
            for kv in strings.split_iterator(&iter, ";") {
                k, _ := style_kv(kv)
                switch k {
                case "ellipse": cell.type = .Ellipse
                case "rhombus": cell.type = .Rhombus
                case "container": incl(&cell.flags, Flag_Value.Container)
                }
            }
        }
    }

    return cell
}