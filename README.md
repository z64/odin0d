# odin0d

This repo is a project organized for the [2023 Handmade Visibility Jam](https://handmade.network/jam) ([Project Entry](https://handmade.network/p/374/odin0d/)).

## Files

- [0d](./0d) - Reference 0d implementation package
- [syntax](./syntax) - Syntax parser based on MxGraph diagrams
- [demo_basics](./demo_basics) - Example using the 0d API manually
- [demo_drawio](./demo_drawio) - Combines `0d` and `diagram` to show off hot loaded control flow based on a draw.io diagram file.

## How To

First, install [Odin](https://odin-lang.org).

There are two programs included:

- [demo_basics](./demo_basics)
- [demo_drawio](./demo_drawio)

You can run each with `odin run demo_basics` or `odin run demo_drawio` at the top level.

`demo_drawio` will read the `example.drawio` file at the top of this repo.

Alternatively, there is a `Makefile` you can use.

### Diagram Editing

First, load up [draw.io](https://draw.io) or download their desktop app.


From their file dialog, you can open the included `example.drawio`.
This is diagram that `demo_drawio` will load at startup.

You can optionally load the included `scratchpad.xml`, which includes some prefabricated pieces of diagram to help you draw quickly.
The scratchpad section is found on the left sidebar.
Press the pencil icon, then "Import" to load the scratchpad file.

**Before you save, open File, Properties, and uncheck "Compressed".**

> The interpreter included does not implement decompression.
> However, this is recommended regardless, as the decompressed diagrams play much nicer with Git, etc.

You can make your edits according to the [Syntax](#syntax) section, then save the diagram back to disk.

### Syntax

The current reference syntax implemented by `demo_drawio` is as follows:

![Syntax Example](https://cdn.discordapp.com/attachments/602932100508942337/1099957457612185670/image.png)

> Note that what follows is a *reference implementation* of a diagram syntax.
> Implementations may choose to be more or less strict, interpret the same diagram differently, lint at compile or runtime, etc.

General rules:

- Components can be in any orientation, size, or colors.
- Components can have any number of inputs and outputs.
- You can "fan out" an output to multiple destinations.
- You can "fan in" an input to a single destination.
- Any extra information (notes, images, ...) in the diagram is ignored.

#### Components

![Component](https://cdn.discordapp.com/attachments/602932100508942337/1099958520406872164/image.png)

Rectangles on the diagram represent Components.
Components are recognized by marking a rectangle as a "container" in draw.io.

The label of the rectangle is an identifier that refers either to native component (Leaf) or another container (page).

You can have multiple components drawn with the same name.
Globally, components with the same name refer to the same leaf code or container.

Ports are recognized as any shape that is a child of this container, that also has some connections:

- Arrows connecting towards the port represent inputs.
  Messages delivered to the input will be seen by the component using the given port name.
- Arrows connecting away from the port represent outputs.
  Messages with matching port names will be delivered along that connection.

This allows some flexibility in how you visually configure ports on the component rect.

Ports can have *any* name:

- Any given port is exclusive to that component (aka port names are not global)
- Input and output ports are exclusive (you can have inputs and outputs with the same names)
- Multiple ports (input or output) with the same name effectively refer to the same port.

#### Containers

![Container](https://cdn.discordapp.com/attachments/602932100508942337/1099962043857129522/image.png)

Each page of the diagram (tab along bottom of the interface) represents a container.
The page name is used as the name of the container.


Inputs to a container are identified using the Rhombus (diamond) shape.
The name on the rhombus identifies the input or output port to the container.

In the above example:

1. Messages to the `main` container are routed to the inputs of `sub1` and `sub2`.
   The pages `sub1` and `sub2` are used as the source for the `sub1` and `sub2` components.
2. The containers described on the `sub1` and `sub2` pages execute and produce outputs.
   These containers may contain other containers and leaf components, recursively.
3. Then, the outputs of those subnetworks are routed to the `stdout` of `main`.

#### Connections

The interpreter looks at the diagram and, using the above rules, interprets the diagram into connections.

In terms of diagram patterns:

- A rhombus, connected to a shape, whose parent is a rect container, is a Down connection.
- A shape, whose parent is a rect container, connected to another shape whose parent is a rect container, is an Across connection.
- A shape, whose parent is a rect container, connected to a rhombus, is an Up connection.
- A rhombus, connected to another rhobus, is a Through connection.

Or, in terms of the runtime:

- Container input to component input is a Down connection.
- Component output to component input is an Across connection.
- Component output to container output is an Up connection.
- Container input directly to container output is a Through connection.

### Runtime

The reference runtime included in the `0d` directory is intended as such.
The demo is intended to communicate the core concepts with minimal LoC.

Since the focus was on making a hot reloading control flow network, type checking of messages is done at runtime as well.
If you route a message to a leaf component with a type that it does not handle, it will currently assert for the purposes of this demo.

Memory management is done by copying message data onto the heap while it is in transit.
When the message is delievered, or no destination for the message is found, it is freed.

Just like normal functions, leaves should be careful to not send pointers to data in the current frame.

Alternative implementations may consider different memory representations for messages or organization of component queues.

## Authors

- Paul Tarvydas - 0d author ([Programming Simplicity Blog](https://publish.obsidian.md/programmingsimplicity/), [GitHub](https://github.com/guitarvydas))
- Zac Nowicki - Odin Implementarion ([Kagi](https://kagi.com), [GitHub](https://github.com/z64))
