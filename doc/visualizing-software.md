# Visualizing Software
- LEGO®-like software components snap together to form apps
- Odin implementation
- draw.io for editing programs
- begin with ultra-simple examples of Hello World, sequential and parallel
- progress to full-blown app, a visual pipeline syntax for Linux ("visual shell")
- 0D library at core (182 lines of Odin, ignoring comments)
- ## Screenshots
![[sequential.png]]
![[parallel.png]]
![[parallel-collapsed.png]]
- ## Video
- ## Install, Use
	- clone repo https://github.com/guitarvydas/odin0d
	- read README.md
	- basically: install draw.io, install Odin, make run
- ## Closing Thoughts
- ### Inspiration
- ### Did It Turn Out Like We'd Hoped?
- ### What Did We Learn?
- ### Future
	- Excalidraw
	- apps run in-the-browser
	- edit in-the-browser
	- Ohm-JS component, Mithril component, etc, etc.
### Team
- Paul Tarvydas - 0d author ([Programming Simplicity Blog](https://publish.obsidian.md/programmingsimplicity/), [GitHub](https://github.com/guitarvydas))
- Zac Nowicki - Odin Implementarion ([Kagi](https://kagi.com), [GitHub](https://github.com/z64))

## Overview
The goal of this project is to visualize software components written in the Odin language and to snap components together like LEGO blocks to form software systems.

We don't visualize *every* piece of Odin code, but concentrate on the bare essentials for visualizing and LEGO-ifying code.

We use draw.io to draw diagrams of software systems.

The code in this project interprets diagrams and runs them as apps.

The 0D concepts can be - easily - extended to code written in other languages.  See the section named "See Also".

There are two main aspects to visualizing software units:
1. Creating a 0D library that allows programmers to write decoupled software units
2. Creating an interpreter that runs diagrams.

Compiler technology is just a subset of interpreter technology.

Creating a 0D library is more important than creating an interpreter or a compiler.  Creating an interpreter and a compiler is just straight-foward *work*.

0D makes it possible to imagine boiler-plate pieces of code.  Compiling boils down to finding and exploiting boilerplates.  Once you can identify boilerplates, e.g. using 0D, you can build an interpreter and a compiler.

In this project, we demonstrate the aspects of 0D and of intrepreting diagrams.  The concept of compiling diagrams follows from the interpreter, with 0D as the runtime system, akin to crt0 in C compilers.


## Basic Concepts Simplified

A *function* is a blob of code.  

Here is a simple example of a function - Echo - that simply returns whatever it receives as input.

```
echo := ...,
      proc(..., message: Message(string)) {
	      send(..., "stdout", message.datum)
	    },
```

The `...` stuff is technical detail that we wish to ignore for now.

Basically, Echo is a `proc` that receives a Message.  As a reaction, the `proc` extracts the data from the Message and sends it back out.  

In this code, Echo uses the `send` function instead of using `return` to return a value.

To make *functions* into *software components*, we simply add input ports and output ports, e.g.

![[fig1.png]]

This basic example is so simple that we need only one input port and only one output port.  In general, though *software components* can have 0, 1, 2, 3, 4, ... input ports and 0, 1, 2, 3, 4, ... output ports.

*Software Components* are completely independent from on another and can be scheduled in any way.  We use arrows to reprsent messages flowing between components.

### Sequential Arrangement
![[fig2.png]]

### Parallel Arrangement
![[fig3.png]]
### Container Components
In the diagrams above, the input arrows seem to come from nowhere and the output arrows seem to go nowhere.

We simply need to wrap the above diagrams in another component.
![[fig4.png]]

We call these kind of *wrapper* components, *Container* components.

Components that aren't *wrappers* are called *Leaf* components. 

### How Do You Write This In Odin?
We wrote Odin procedures for the above diagrams.  

```
package zd

import "core:fmt"
import "core:slice"

main :: proc() {
    fmt.println("--- Handmade Visibility Jam")
    fmt.println("--- Sequential")
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
    fmt.println("--- Parallel")
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
}
```

```
$ make runbasic 
./demo_basics.bin
*** Handmade Visibility Jam ***
--- Sequential
[{stdout, hello}]
--- Parallel
[{stdout, hello}, {stdout, hello}]
$ 
```

all of the code is in https://github.com/guitarvydas/odin0d

N.B. The `.up`/`.down`/`.across` stuff is the way we describe how diagram arrows connect to Components.  We enable the concept of *layering* and *nesting*, which means that we needed to dissect - in detail - how data is routed in 4 combinations (out->in, in->in, out->out, container-level-in->container-level-out).  Describing arrows this way mimics what we intuitively see on diagrams.

### Code Grind-Through

Let's begin with the sequential version...

```
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
    fmt.println("*** Handmade Visibility Jam ***"
    fmt.println("--- Sequential")
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
    ...
}
```

In our opinion, the program - written out as ASCII Odin textual source code - ain't as readable as the diagram.

The first few lines - `package`, `imports` and `::` stuff - is a bunch of details required to appease the Odin compiler and to write code in a non-layered manner[^fl].

[^fl]: Or, if you wish, fake layering using text instead of rectangles.

Then, we see some lines of code that declare the `main` procedure and print out a banner. (`main :: ...`, `fmt. ...`, `fmt. ...`)

Then we see ASCII `{ ... }`, meaning "box".

What is seen inside the box, is the text code required to build a Container called "top" which contains two Leaf components, both almost the same.  The two Leaf components have slightly different names - "10" and "11" - which are actually redundant, since the Leaf's unique identities can be determined by their coordinates (X and Y ; and if you're really ambitious, x/y/z/t).  Names are there only to appease human readers during bootstrap.  The machine doesn't care whether the names are readable or not.  In the end, names will not be needed.

The lines 
```
        echo0 := make_leaf("10", echo_handler)
        echo1 := make_leaf("11", echo_handler)
```
create two children Leaf Components by specifiying a handler proc to be used.  In this case, we can use the same proc twice, since we want each Leaf to do exactly the same thing.

The lines:
```
	top := make_container("Top", string)

    top.children = {
...
    top.connections = {
...
```
create the Container called "top" and supply 3 pieces of information
1. the boilerplate code `make_container(...)`
2. a list of the children within the Container
3. a routing map between the children and/or the Container.

Each connection is described by 3 details:
2. from (a Component)
3. to (a Component)
1. path (.Down, .Up, .Across)

We call the routing map "connections".

Then, we send a message to the `top` component on its port "stdin".  The message is the string "hello".

When the `top` component finishes running, we execute one more line of code.
```
print_output_list(output_list(top))
```
This line of code retrieves the output messages from `top` and prints them on the console.

We can run this example in the following way:
```
$ make runbasic 
./demo_basics.bin
*** Handmade Visibility Jam ***
--- Sequential
[{stdout, hello}]
--- Parallel
[{stdout, hello}, {stdout, hello}]
$
```

Note that runbasic runs both, the sequential and parallel versions of the program.

### Parallelism
The parallel  version of this system is almost the same, except for rewiring.  

The routing table is different.  It connects top's "stdin" to the "stdin" of its two children.  It connects the "stdout" port of both children to top's only output "stdout".

```
{.Down, {nil, "stdin"},              {&top.children[0].input, "stdin"}},
{.Down, {nil, "stdin"},              {&top.children[1].input, "stdin"}},
{.Up,   {top.children[0], "stdout"}, {&top.output, "stdout"}},
{.Up,   {top.children[1], "stdout"}, {&top.output, "stdout"}},
```

### Meaning of Connections
#### Down
```
{.Down,   {nil, "stdin"},              {&top.children[0].input, "stdin"}},
```
A *down* connection is used by a Container to punt messages to its children.

In this example, any message that arrives on "top"s "stdin" input will be punted to the "stdin" input of the 0th child Echo.

#### Across
```
{.Across, {top.children[0], "stdout"}, {&top.children[1].input, "stdin"}},
```
An *across* connection is used to send messages from one child to another.

In this example, the 0th child's output messages on "stdout" are routed to the 1th child's "stdin" input.

Note that no child is allowed to control *where* the messages go.  Routing decisions are made *only* by their parent containers.

#### Up
```
{.Up,     {top.children[1], "stdout"}, {&top.output, "stdout"}},
```
An *up* connection is used to send messages from one child to the output of its parent container.

In this example, output from the 1th child's "stdout" port is deposited on top's "stdout" output port.

## How Do We Write This Program In Draw.IO?
We use ellipses for ports, rectangles for components, rhombuses for container ports and arrows for connections.

We don't bother to label connections with their path information.  That information is "obvious" from the diagram.

A limitation of draw.io is that it can't drill-down into Container components.  Ideally, double-clicking on a Container should bring up another diagram, while double-clicking on a Leaf should bring up a code editor.

We make do with draw.io's limitations.  To view the insides of a Container, you must select a tab at the bottom of the draw.io editor.  To view the insides of a Leaf, you have to open your favourite text editor on the Odin code that implements the Leaf.  Draw.io doesn't make it easy to arrange Containers in some sort of hierarchy.

### Sequential Program Written In Draw.IO

![[sequential.example.png]]

### Parallel Program Written in Draw.IO

![[parallel.example.png]]


## Full-Blown App
We will use the above techniques to write the beginnings of a Visual Shell for Linux.

Background: Decades ago, one of the authors created a demo called *vsh* (Visual Shell) using a mish-mash of technologies including the `yEd` diagram editor, `PROLOG` and `C`.  The Visual Shell was conquer-and-divided into 2 parts:
1. diagram compiler
2. assembler - to convert compiler output to Linux system calls.

Due to the time limitations, we'll spiral in from the top-down, to re-implement this app.  We'll stop when we run out of time.  Maybe we'll continue to finish this code after the Jam.

![[visualizing-software 2023-04-16 05.03.39.excalidraw.png|400]]

### Scan
- convert yEd file, pl_vs.graphml, into a factbase 
	- triples, { relation, subject, object }
- discard majority of information - editing-only details
### Check Input
- noop - throws error if any input is malformed
- simplistic check during bootstrapping, to see that previous pass, Scan, was working as expected
### Calc Bounds
- calculate bounding boxes for all closed figures (not arrows)
```
...
createBoundingBoxes :-
  forall(geometry_x(ID, X), createBoundingBox(ID, X)).
createBoundingBox(ID, X) :-
  geometry_y(ID, Y),
  geometry_w(ID, Width),
  geometry_h(ID, Height),
  asserta(bounding_box_left(ID,X)),
  asserta(bounding_box_top(ID,Y)),
  Right is X + Width,
  Bottom is Y + Height,
  asserta(bounding_box_right(ID,Right)),
  asserta(bounding_box_bottom(ID,Bottom)).
...
```
- capitalized variables are Logic Variables (engine performs assignment during pattern matching)
- Logic Variables are "holes" that get filled in during pattern matching
- all Logic Variables with the same name must contain the same value for the whole relation to succeed (the engine keeps trying matches until everything is self-consistent)
- `asserta` creates new relations in the factbase
- elided code reads in the factbase from *stdin* at beginning, and, writes out the factbase to *stdout* when done
### Mark Directions
a "source" is a component pin that produces events (IPs) and a "sink" is the destination
for events. We avoid the more obvious terms "input" and "output" because the terms are
ambiguous in hierarchical components, e.g. an input pin on the outside of a hierarchial
component looks like it "outputs" events to any components contained within the hierarchical component.
yEd creates edges with clearly delineated sources and sinks, hence, this pass is
redundant for this particular application (using yEd); just read and re-emit all facts
### Match Ports To Components
```
match_ports :-
    % assign a parent component to every port, port must intersect parent's bounding-box
    % unimplemented semantic check: check that every port has exactly one parent
    forall(eltype(PortID, port),assign_parent_for_port(PortID)).

assign_parent_for_port(PortID) :-
    bounding_box_left(PortID, Left),
    bounding_box_top(PortID, Top),
    bounding_box_right(PortID, Right),
    bounding_box_bottom(PortID, Bottom),
    bounding_box_left(ParentID, PLeft),
    bounding_box_top(ParentID, PTop),
    bounding_box_right(ParentID, PRight),
    bounding_box_bottom(ParentID, PBottom),
    eltype(ParentID, box),
    intersects(Left, Top, Right, Bottom, PLeft, PTop, PRight, PBottom),
    asserta(parent(PortID, ParentID)).

intersects(PortLeft, PortTop, PortRight, PortBottom, ParentLeft, ParentTop, ParentRight, ParentBottom) :-
    % true if child bounding box center intersect parent bounding box
    % bottom is >= top in this coord system
    % the code below only checks to see if all edges of the port are within the parent box
    % this should be tightened up to check that a port actually intersects one of the edges of the parent box
    PortLeft =< ParentRight,
    PortRight >= ParentLeft,
    PortTop =< ParentBottom,
    PortBottom >= ParentTop.
```
### Assign Pipe Numbers to Inputs
```
main :-
    g_assign(counter,0),
    readFB(user_input),
    forall(sink(_,Pin),assign_pipe_number(Pin)),
    g_read(counter,N),
    asserta(npipes(N)),
    writeFB,
    halt.

assign_pipe_number(Pin) :-
    g_read(counter,Old),
    asserta(pipeNum(Pin,Old)),
    inc(counter,_).
```
### Assign Pipe Numbers to Outputs
```
aopn(P) :- 
    sink(E,P), 
    pipeNum(P,I),
    source(E,O),
    asserta(pipeNum(O,I)).
    
writeterm(Term) :- current_output(Out), write_term(Out, Term, []), write(Out, '.'), nl.
```
### Assign FDs
```
% Assigns FD's to each port.  Special cases: "in" is assigned 0, "out"
% is assigned 1, "err" is assigned 2 and beyond that a new fd number is
% generated starting at 3 (untested at this time).
% 
% Augments factbase with:
% 
% (source-fds <id> ((pipe . fd) (pipe . fd) ...))
% (sink-fds <id> ((pipe . fd) (pipe . fd) ...))
% 
% where "pipe" and "fd" are integers.  The (x . y) notation represents a
% pair (2-tuple).
% 

main :-
    g_assign(fdnum,3),  % non-special case fd's start at 3 and up to maximum
    readFB(user_input),
    forall(portName(P,in),assign_sink_fd(P,0)), % stdin == 0
    forall(portName(P,out),assign_source_fd(P,1)), % stdout == 1
    forall(portName(P,err),assign_source_fd(P,2)), % stderr == 2

    %-- still thinking about this one - what about non-std fd's?
    %-- are the ports per-component?  Are they named at the architectural level?

    writeFB,
    halt.

assign_source_fd(P,N) :-
    %write(P), write(' '), write(N), nl,
    asserta(sourcefd(P,N)).

assign_sink_fd(P,N) :-
    %write(P), write(' '), write(N), nl,
    asserta(sinkfd(P,N)).
```
### Emit Grash
This version compiled yEd diagrams to .gsh source code.

Grash.c interpreted the .gsh source code at runtime and called the appropriate Linux system calls.

```
main :-
    readFB(user_input),
    write('#name '),
    component(Name),
    write(Name),
    write('.gsh'),
    nl,
    npipes(Npipes),
    write('pipes '),
    write(Npipes),
    nl,
    forall(kind(ID,_),emitComponent(ID)),
    halt.

writeIn(In) :-
    writeSpaces,
    portName(In,in),
    pipeNum(In,Pipe),
    write('stdinPipe'),
    write(' '),
    write(Pipe),
    nl.

writeOut(Out) :-
    writeSpaces,
    portName(Out,out),
    pipeNum(Out,Pipe),
    write('stdoutPipe'),
    write(' '),
    write(Pipe),
    nl.

writeErr(Out) :-
    writeSpaces,
    portName(Out,out),
    pipeNum(Out,Pipe),
    write('stderrPipe'),
    write(' '),
    write(Pipe),
    nl.

emitComponent(ID) :-
    write('fork'),
    nl,
    forall(inputOfParent(ID,In),writeIn(In)),
    forall(outputOfParent(ID,O),writeOut(O)),
    forall(erroutputOfParent(ID,Out),writeErr(Out)),
    writeSpaces,
    writeExec(ID),
    write(' '),
    kind(ID,Name),
    write(Name),
    nl,
    write('krof'),
    nl.

writeSpaces :- char_code(C,32), write(C), write(C).

inputOfParent(P,In) :-
    parent(In,P),portName(In,in).
    
outputOfParent(P,Out) :-
    parent(Out,P),portName(Out,out).
    
erroutputOfParent(P,Out) :-
    parent(Out,P),portName(Out,err).
    
writeExec(ID) :-
    hasInput(ID),write(exec),!.
writeExec(_) :-
    write(exec1st),!.

hasInput(ID) :-
    eltype(ID,box),
    parent(Port,ID),
    eltype(Port,port),
    sink(_,Port).

```
### Grash.c
```
/*
  GRAph SHell - a Flow-Based Programming shell
  (See https://www.cs.rutgers.edu/~pxk/416/notes/c-tutorials/pipe.html 
  section "Creating a pipe between two child processes" for a explanation
  of how to use dup2, etc.).
  A *nix shell that reads scripts of simple commands that plumb
  commands together with a graph of pipes / sockets / etc.
  This shell is not intended for heavy human consumption, but as an assembler
  that interprets programs created by graphical Flow-Based Programming
  (FBP) tools.
  Commands to the interpreter
  comments: # as very first character in the line
  empty line
  pipes N : creates N pipes starting at index 0
  push N : push N as an arg to the next command (dup)
  dup N : dup2(pipes[TOS][TOS-1],N), pop TOS, pop TOS
          pipes[x][y] : x is old pipe #, y is 0 for read-end, 1 for write-end, etc.
          N is the new (child's) FD to be overwritten with the dup'ed pipe (0 for stdin, 1 for stdout, etc).
  stdinPipe N - shorthand for above ; dup2(pipes[N][0],0)
  stdoutPipe N - shorthand for above ; dup2(pipes[N][1],1)
  stderrPipe N - shorthand for above ; dup2(pipes[N][2],2)
  exec <args> : splits the args and calls execvp, after closing all pipes
  exec1st <args> : splits the args, appends args from the command line and calls execvp, after closing all pipes
  fork : forks a new process
         parent ignores all subsequent commands until krof is seen
  krof : signifies end of forked child section
         parent resumes processing commands
	 child (if not exec'ed) terminates
*/

#define PIPEMAX 100
#define LINEMAX 1024
#define ARGVMAX 128
#define STACKMAX 2

#define READ_END 0
#define WRITE_END 1

int comment (char *line) {
  /* return 1 if line begins with # or is empty, otherwise 0 */
  return line[0] == '#' || line[0] == '\n' || line[0] == '\0';
}

char *parse (char *cmd, char *line) {
  /* if command matches, return pointer to first non-whitespace char of args */
  while (*cmd)
    if (*cmd++ != *line++)
      return NULL;
  while (*line == ' ') line++;
  return line;
}

int pipes[PIPEMAX-1][2];
int usedPipes[PIPEMAX-1];
int child;
#define MAIN 1
#define PARENT 2
#define CHILD 3
int state = MAIN;
int stack[STACKMAX];
int sp = 0;

void quit (char *m) {
  perror (m);
  exit (1);
}

void push (char *p) {
  assert (sp < STACKMAX);
  stack[sp++] = atoi(p);
}

int pop () {
  assert (sp > 0);
  return stack[--sp];
}

void gclose (char *p) {
  int i = atoi(p);
  close(pipes[i][0]);
  close(pipes[i][1]);
}

void gdup (char *p) {
  int fd = atoi(p);
  int i = pop();
  int dir = pop();
  int oppositeDir = ((dir == READ_END) ? WRITE_END : READ_END);
  dup2 (pipes[i][dir], fd);
  close(pipes[i][oppositeDir]);  // flows are one-way only
  usedPipes[i] = 1;
}

void gdup_std (char *p, int fd, int dir) {
  int i = atoi(p);
  int oppositeDir = ((dir == READ_END) ? WRITE_END : READ_END);
  dup2 (pipes[i][dir], fd);
  close(pipes[i][oppositeDir]);  // flows are one-way only
  usedPipes[i] = 1;
}

void gdup_stdin (char *p) {
  gdup_std (p, 0, READ_END);
}

void gdup_stdout (char *p) {
  gdup_std (p, 1, WRITE_END);
}

void gdup_stderr(char *p) {
  gdup_std (p, 2, WRITE_END);
}


int highPipe = -1;

void mkPipes (char *p) {
  int i = atoi(p);
  if (i <= 0 || i > PIPEMAX)
    quit("socket index");
  highPipe = i - 1;
  i = 0;
  while (i <= highPipe)
    if (pipe (pipes[i++]) < 0)
      quit ("error opening pipe pair");
}

void closeAllPipes () {
  // close all pipes in pipe array owned by the parent
  int i;
  for (i = 0 ; i <= highPipe ; i++) {
    close (pipes[i][READ_END]);
    close (pipes[i][WRITE_END]);
  }
}
	   
void closeUnusedPipes () {
  int i;
  for (i = 0 ; i <= highPipe ; i++) {
    if (usedPipes[i] == 0) {
      close (pipes[i][READ_END]);
      close (pipes[i][WRITE_END]);
    }
  }
}
	   

void doFork () {
  if ((child = fork()) == -1)
    quit ("fork");
  state = (child == 0) ? PARENT : CHILD;
}

void doKrof () {
  state = MAIN;
}

char *trim_white_space(char *p) {
  while (*p == ' ' || *p == '\t' || *p == '\n') {
    *p++ = '\0';
  }
  return p;
}

void  parseArgs(char *line, int *argc, char **argv) {
  /* convert the char line into argc/argv */
  *argc = 0;
  while (*line != '\0') {
    line = trim_white_space(line);
    if (*line == '\0') {
      break;
    }
    *argv++ = line;
    *argc += 1;
    while (*line != '\0' && *line != ' ' && 
	   *line != '\t' && *line != '\n') 
      line++;
  }
  *argv = NULL;
}
  
void appendArgs (int *argc, char **argv, int oargc, char **oargv) {
  /* tack extra command-line args onto tail of argv, using pointer copies */
  fprintf (stderr, "oargc=%d\n", oargc);
  fflush (stderr);
  if (oargc > 2) {
    int i = 2;
    while (i < oargc) {
      argv[*argc] = oargv[i];
      *argc += 1;
      i += 1;
    }
    argv[i] = NULL;
  }
}

void doExec (char *p, int oargc, char **oargv, int first) {
  char *argv[ARGVMAX];
  int argc;
  pid_t pid;
  int i;
  parseArgs (p, &argc, argv);
  if (first) {
    appendArgs (&argc, argv, oargc, oargv);
  }
  closeUnusedPipes();

  fprintf (stderr, "execing[%d]:", argc);
  fflush (stderr);
  for(i=0; i < argc; i+=1) {
    fprintf (stderr, " %s", argv[i]);
    fflush (stderr);
  }
  fprintf (stderr, "\n");
  fflush (stderr);

  pid = execvp (argv[0], argv);
  if (pid < 0) {
    fprintf (stderr, "exec: %s\n", argv[0]);
    quit ("exec failed!");
  }
}

void interpret (char *line, int argc, char **argv) {
  char *p;

  line = trim_white_space(line);

  if (comment (line))
    return;

  switch (state) {

  case CHILD:
    p = parse ("krof", line);
    if (p)
      exit(0);
    p = parse ("dup", line);
    if (p) {
      gdup (p);
      return;
    }
    p = parse ("stdinPipe", line);
    if (p) {
      gdup_stdin (p);
      return;
    }
    p = parse ("stdoutPipe", line);
    if (p) {
      gdup_stdout (p);
      return;
    } 
    p = parse ("stderrPipe", line);
    if (p) {
      gdup_stderr (p);
      return;
    }
    p = parse ("push", line);
    if (p) {
      push (p);
      return;
    }
    p = parse ("exec1st", line);
    if (p) {
      doExec (p, argc, argv, 1);
      return;
    }
    p = parse ("exec", line);
    if (p) {
      doExec (p, argc, argv, 0);
      return;
    }
    quit("can't happen");
    break;

  case MAIN:
    p = parse ("pipes", line);
    if (p) {
      mkPipes (p);
      return;
    }
    p = parse ("fork", line);
    if (p) {
      doFork ();
      return;
    }
    p = parse ("krof", line);
    if (p)
      quit ("krof seen in MAIN state (can't happen)");
    break;

  case PARENT:
    p = parse ("krof", line);
    if (p) {
      doKrof ();
      return;
    }
    return;
  }
  quit ("command");
}
  

int main (int argc, char **argv) {
  int r;
  char line[LINEMAX-1];
  char *p;
  FILE *f;
  pid_t pid;
  int status;

  if (argc < 2 || argv[1][0] == '-') {
    f = stdin;
  } else {
    f = fopen (argv[1], "r");
  }
  if (f == NULL)
    quit ("usage: grash {filename|-} [args]");

  for (r = 0; r < PIPEMAX; r++) {
    pipes[r][READ_END] = -1;
    pipes[r][WRITE_END] = -1;
    usedPipes[r] = 0;
  }
  
  p = fgets (line, sizeof(line), f);
  while (p != NULL) {
    interpret (line, argc, argv);
    p = fgets (line, sizeof(line), f);
  }
  closeAllPipes();
  while ((pid = wait(&status)) != -1) {
    fprintf(stderr, "%d exits %d\n", pid, WEXITSTATUS(status));
  }
  exit(0);
}
```
### Previous Version
https://github.com/guitarvydas/vsh
- pl_vsh contains PROLOG version
- cl-vsh contains Common Lisp version
- grash contains grash.c assembler

This previous version created components as Linux commands as binaries in ~/bin and used Linux/shell/pipelines to run 0D components.
#### PT temporary
![[visualizing-software 2023-04-16 05.03.39.excalidraw]]
![[vsh.excalidraw]]

# Appendices
### The Through Connection

This example does not show a 4th kind of connection - *through*.  This kind of connection is used to send a message from the input of a container directly to its own output.

## ė
An ė (pronounced *eh* in ASCII) component is like a *lambda* that has one input queue and one output queue.
![[fig5.png]]


## 0D
0D - Zero Dependency - in a nutshell is total decoupling.

https://publish.obsidian.md/programmingsimplicity/2022-11-28-0D+Q+and+A
https://publish.obsidian.md/programmingsimplicity/2023-01-24-0D+Ideal+vs.+Reality
https://publish.obsidian.md/programmingsimplicity/2022-08-30-Decoupling
https://publish.obsidian.md/programmingsimplicity/2022-07-11-0D

## Messages
Messages are pairs:
1. port (e.g.name as a String, or an ID that it more efficient in a given context)
2. data (anything)

## How Ports Work

Each Component - Container or Leaf - has a single input queue, and, a single output queue.

Messages are enqueued on the queues, along with their port names.

Note that there is only one input queue and one output queue per component, not one queue per port.

There is no concept of *priority* for messages.  If prioritization is required, it must be explicitly programmed by the Architect/Engineer on a per-project basis.

The goal of this work to is allow the Architect/Engineer to decide, on a per-project basis, what needs to be done.  The goal is to provide a set of simple, low-level operations that can be composed by the Architect/Engineer to solve specific problems.  Generality and general-purpose programming are to be eschewed.

## Drawing Compiler
The Big Bang For The Buck is simply that of drawing diagrams.  Having a compiler which compiles diagrams to code is only a nice-to-have, but, not essential.  

In this jam, we show how to use one specific drawing editor - draw.io - to build programs as diagrams.  Other editors could be used, such as Excalidraw, Kinopio, yEd, etc.  Each existing editor has some advantages and some drawbacks.  Of these choices, Kinopio seems to embody the concepts of nesting and web-ification, but, Kinopio is not actually targeted at diagramming.  Maybe this work will inspire new ideas for DaS editing (Diagrams as Syntax).

In this project, a simple diagram interpreter was implemented in Odin.  Most diagram editors can produce JSON or XML, which makes their diagrams easily parse-able by existing text-only parsing tools.

Our favoured text-only parsing tool is, currently, Ohm-JS. 

## Scheduling
Components can be scheduled in any way desired by the Software Architect.

Projects are constructed by snapping components together, in manner similar to using LEGO blocks to construct various toy structures.
## Routing
The Big Secret in this work is the idea that there are 2 kinds of components:
1. Leaf - general purpose code that produces output messagesm instead of using `return`
2. Container -  contains children components and handles all routing between children.

Children cannot refer to other components.  No Name Calling.  This simple rule enhances flexibility. 

https://publish.obsidian.md/programmingsimplicity/2023-04-08-The+Benefits+of+True+Decoupling
## Feedback
An interesting outcome of this technique is the use of feedback (which is not the same as recursion).
https://publish.obsidian.md/programmingsimplicity/2023-04-02-Feedback

## See also
Versions of 0D have been constructed for Python and for Common Lisp.

As it stands, the Common Lisp version is the most recent version (non-Odin). This version eschews the use of *self*, making 0D amenable to non-OO languages.

see also: Py0D, CL0D.

https://github.com/guitarvydas/py0d
https://github.com/guitarvydas/cl0d

## Summary (kagi.com Summarizer)
This document presents a package called "zd" that provides a framework for building event-driven systems in the Odin programming language. The package includes several data structures and procedures for creating and managing event handlers (Eh), which can be either containers or leaves. Containers can have child Eh instances and connections to other Eh instances, while leaves are standalone handlers. The package also includes a FIFO data structure for message queues and a Connector data structure for connecting Eh instances. The procedures provided by the package include methods for enqueueing and dequeuing messages, clearing message queues, and checking if queues are empty. The package also includes a container_dispatch_children procedure for routing messages to child Eh instances and a container_route procedure for depositing messages into Connector instances. Finally, the package includes a container_any_child_ready procedure for checking if any child Eh instances are ready to receive messages and a container_child_is_ready procedure for checking if a specific Eh instance is ready to receive messages.
