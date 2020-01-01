# Brainfuck in the Boot Sector

This is a (mostly) functional BF interpreter that's run entirely on the
boot sector.

Bootstrapped off of https://github.com/belamenso/nasm-bfi by belamenso.

See `boot.asm` for implementation details.

## Build and Run

```sh
$ nasm -f bin boot.asm -o boot.bin
$ qemu-system-x86_64 boot.bin  # or qemu-system-i686
```

*Alt+2, then 'q' then 'ENTER' to exit QEMU.*

## Usage

**Type or copy and paste BF code into the window, then hit `ENTER` to
interpret.**

Try copying this `Hello World` example:

```
++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.
```

If there is anything that should be printed, it will appear next to the
`Output>` at the top of the prompt.

After execution, the instructions will still be on the prompt, but you can
overwrite the instructions.

Also after execution, the state of the tape will not reset back to how it was at
startup, so you can constantly change it with every interpretter run.

- *As a result of this, it could technically be possible to get stuck in an
  infinite loop of you hit `ENTER` a couple of times on the same `Hello world`
  code.*

## Constraints

A lot of corners had to be cut obviously for the sake of fitting it all into 512
bytes. Here are some of them:

- The tape that the BF code is only (at least) 64 bytes (instead of the 30000
  recommended on the wiki). This could technically be expanded though as the
  remainder of the kernel if I kept reading from more boot sectors ;)
- Instead of also dedicating a section in the bootsector for storing BF code to
  be interpretted, I opted for instead just reading them off the screen using
  the various `int 0x10` interupt functions.
- I have not registered arrow key inputs for the terminal.
- I have not implemented any sort of checks for balanced `[`s and `]`s.
- To avoid printing characters that could set the cursor past the Output line in
  the terminal, I only print the original character if `' ' <= char <= '~'`.
  This avoids printing stuff like newlines or carriage returns.
