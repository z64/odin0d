/*

This package parses diagrams in `MxGraph` format, returning structured
information for interpreting the diagram into control flow diagrams.

Primarily tested against diagrams produced by https://draw.io.
Other sources may or may not work.

Currently the cells parsed by this package include:

- Rects
- Rhombus
- Ellipse
- Arrow

All other information in the diagram is ignored.

The cells themselves may have any value, and be styled in any manner.

*/
package diagram

import "core:encoding/xml"
import "core:strings"
import "core:slice"
import "core:os"

// Reads the given XML file, producing a set of pages of each diagram
// contained within.
read_from_xml_file :: proc(path: string) -> (pages: []Page, ok: bool) {
    file := os.read_entire_file(path) or_return

    xml, err := xml.parse(file)
    if err != nil do return

    pages = diagrams_from_document(xml)
    return pages, true
}

Page :: struct {
    name:  string,
    cells: []Cell,
}

Cell :: struct {
    mxgraph_id:     string,
    mxgraph_source: string,
    mxgraph_target: string,
    value:          string,
    styles:         map[string]string,
    id:             int,
    source:         int,
    target:         int,
    flags:          Flag_Set,
    type:           Cell_Type,
}

Cell_Type :: enum {
    Unknown,
    Rhombus,
    Rect,
    Ellipse,
    Arrow,
}

Flag_Value :: enum {
    Vertex,
    Edge,
    Parent,
}

Flag_Set :: bit_set[Flag_Value]

cell_from_elem :: proc(elem: xml.Element) -> Cell {
    style_map :: proc(s: string) -> map[string]string {
        m := make(map[string]string)
        iter := s
        for kv in strings.split_iterator(&iter, ";") {
            idx := strings.index(kv, "=")
            if idx == -1 {
                m[kv] = ""
            } else {
                k := kv[:idx]
                v := kv[idx+1:]
                m[k] = v
            }
        }
        return m
    }

    cell: Cell

    for attrib in elem.attribs {
        switch attrib.key {
        case "id":     cell.mxgraph_id = attrib.val
        case "source": cell.mxgraph_source = attrib.val
        case "target": cell.mxgraph_target = attrib.val
        case "value":  cell.value = attrib.val
        case "vertex": incl(&cell.flags, Flag_Value.Vertex)
        case "edge":   incl(&cell.flags, Flag_Value.Edge)
        case "parent": incl(&cell.flags, Flag_Value.Parent)
        case "style":  cell.styles = style_map(attrib.val)
        }
    }

    cell.type = .Rect

    if .Edge in cell.flags {
        cell.type = .Arrow
    }

    if _, ok := cell.styles["ellipse"]; ok {
        cell.type = .Ellipse
    }

    if _, ok := cell.styles["rhombus"]; ok {
        cell.type = .Rhombus
    }

    return cell
}

diagrams_from_document :: proc(doc: ^xml.Document) -> []Page {
    array: [dynamic]Page

    for elem in doc.elements {
        if elem.ident != "root" {
            continue
        }

        diagram: Page

        // find name
        parent0 := doc.elements[elem.parent]
        parent1 := doc.elements[parent0.parent]
        assert(parent1.ident == "diagram", "Unexpected XML layout (root diagram name)")
        for attr in parent1.attribs {
            if attr.key == "name" {
                diagram.name = attr.val
                break
            }
        }
        assert(diagram.name != "", "Diagram without name")

        // find children
        diagram.cells = make([]Cell, len(elem.children))
        for child_id, idx in elem.children {
            elem := doc.elements[child_id]
            assert(elem.ident == "mxCell", "Unexpected XML layout (root children)")
            diagram.cells[idx] = cell_from_elem(elem)
        }

        // sort & assign IDs
        slice.sort_by(diagram.cells, proc(i, j: Cell) -> bool {
            return i.type < j.type
        })
        for cell, idx in &diagram.cells {
            cell.id = idx
        }

        // connect source/target references
        for cell in &diagram.cells {
            if cell.mxgraph_source != "" {
                for x in diagram.cells {
                    if x.mxgraph_id == cell.mxgraph_source {
                        cell.source = x.id
                    }
                }
            }

            if cell.mxgraph_target != "" {
                for x in diagram.cells {
                    if x.mxgraph_id == cell.mxgraph_target {
                        cell.target = x.id
                    }
                }
            }
        }

        append(&array, diagram)
    }

    return array[:]
}
