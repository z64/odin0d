## Full-Blown App
We will use the above techniques to write the beginnings of a Visual Shell for Linux.

Background: Decades ago, one of the authors created a demo called *vsh* (Visual Shell) using a mish-mash of technologies including the `yEd` diagram editor, `PROLOG` and `C`.  The Visual Shell was conquer-and-divided into 2 parts:
1. diagram compiler
2. assembler - to convert compiler output to Linux system calls.

Due to the time limitations, we'll spiral in from the top-down, to re-implement this app.  We'll stop when we run out of time.  Maybe we'll continue to finish this code after the Jam.

![visualizing-software 2023-04-16 05.03.39.excalidraw.png](https://hmn-assets-2.ams3.cdn.digitaloceanspaces.com/0df893ac-6d2d-4727-886a-4e0537c8fa37/visualizing-software_2023-04-16_05.03.39.excalidraw.png)


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
