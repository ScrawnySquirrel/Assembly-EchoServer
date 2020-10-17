# Assembly-EchoServer
Simple Assembly code for a client-server echo application.
The client sends the message to the server and the server simply echo back the message to the client.

## Prerequisite
 * nasm

## How to run
### Server
1. nasm -f elf64 -o server.o server.asm
2. ld server.o -o server
3. ./server

### Client
1. nasm -f elf64 -o client.o client.asm
2. ld client.o -o client
3. ./client <server IP>

> The server IP format uses whitespace as a separator character instead of the dot character. i.e. *192 168 1 69*

## Author

**Gabriel Lee** - [ScrawnySquirrel](https://github.com/ScrawnySquirrel)
