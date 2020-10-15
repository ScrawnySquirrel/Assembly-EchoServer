%include 'functions.asm'

;; TCP echo server using x86_64 Linux syscalls
;; Assemble and link as follows:
;;        nasm -f elf64 -o server.o server.asm
;;        ld server.o -o server
;;
;;

global _start

;; Data definitions
struc sockaddr_in
    .sin_family resw 1
    .sin_port resw 1
    .sin_addr resd 1
    .sin_zero resb 8
endstruc

section .bss
    sock resw 2
    server resw 2
    echobuf resb 256
    read_count resw 2

    ipaddr resd 2
    pStruc resd 1

section .data
    sock_err_msg        db "Failed to initialize socket", 0x0a, 0
    sock_err_msg_len    equ $ - sock_err_msg

    connect_err_msg      db "Connect Failed", 0x0a, 0
    connect_err_msg_len  equ $ - connect_err_msg

    accept_msg          db "Client Connected!", 0x0a, 0
    accept_msg_len      equ $ - accept_msg

    ip_msg          db "IP: "
    ip_msg_len      equ $ - ip_msg

    client_prompt          db "Client message: "
    client_prompt_len      equ $ - client_prompt

    server_prompt          db "Server message: "
    server_prompt_len      equ $ - server_prompt


    ;; sockaddr_in structure for the address the listening socket binds to
    pop_sa istruc sockaddr_in
        at sockaddr_in.sin_family, dw 2           ; AF_INET
        at sockaddr_in.sin_port, dw 0xce56        ; port 22222 in host byte order
        at sockaddr_in.sin_addr, dd 0             ; localhost - INADDR_ANY
        ; at sockaddr_in.sin_addr, dd 0x4501A8C0             ; localhost - INADDR_ANY
        at sockaddr_in.sin_zero, dd 0, 0
    iend
    sockaddr_in_len     equ $ - pop_sa

section .text

;; Sever main entry point
_start:
    ;; Initialize listening and client socket values to 0, used for cleanup
    mov      word [sock], 0
    mov      word [server], 0

    ;; Initialize socket
    call     _socket

    ;; Get IP addr from user
    call _get_ip

    ;; Main loop handles connection requests (accept()) then echoes data back to client
    .mainloop:
        mov dword [pop_sa + sockaddr_in.sin_addr], 0x4501A8C0
        call     _connect

        ;; Read and echo string back to the client
        ;; up the connection on their end.
        .readloop:
            call _get_msg
            call     _echo
            call _read

            ;; read_count is set to zero when client hangs up
            mov     rax, [read_count]
            cmp     rax, 0
            je      .read_complete
        jmp .readloop

        .read_complete:
        ;; Close client socket
        mov    rdi, [server]
        call   _close_sock
        mov    word [server], 0
    jmp    .mainloop

    ;; Exit with success (return 0)
    mov     rdi, 0
    call     _exit

;; Performs a sys_socket call to initialise a TCP/IP listening socket.
;; Stores the socket file descriptor in the sock variable
_socket:
    mov         rax, 41     ; SYS_SOCKET
    mov         rdi, 2      ; AF_INET
    mov         rsi, 1      ; SOCK_STREAM
    mov         rdx, 0
    syscall

    ;; Check if socket was created successfully
    cmp        rax, 0
    jle        _socket_fail

    ;; Store the new socket descriptor
    mov        [sock], rax

    ret

;; Accept a cleint connection and store the new client socket descriptor
_connect:
    mov rax, 42 ; SYS_CONNECT – 64-bit
    mov rdi, [sock] ; listening socket fd
    mov rsi, pop_sa ; pop_sa would contain the addressing information
    mov rdx, sockaddr_in_len ; socklen_t
    syscall

    ;; Check if call succeeded
    cmp       rax, 0
    jl        _connect_fail

    ;; Store returned client socket descriptor
    mov     [server], rax

    ;; Print connection message to stdout
    mov       rax, 1             ; SYS_WRITE
    mov       rdi, 1             ; STDOUT
    mov       rsi, accept_msg
    mov       rdx, accept_msg_len
    syscall

    ret

;; Reads up to 256 bytes from the client into echobuf and sets the read_count variable
;; to be the number of bytes read by sys_read
_read:
    ;; Call sys_read
    mov     rax, 0          ; SYS_READ
    mov     rdi, [sock]   ; client socket fd
    mov     rsi, echobuf    ; buffer
    mov     rdx, [read_count]        ; read [read_count] bytes
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, server_prompt
    mov rdx, server_prompt_len
    syscall

    mov rax, 1
    mov rdi, 1
    mov rsi, echobuf
    mov rdx, [read_count]
    syscall

    ret

;; Sends up to the value of read_count bytes from echobuf to the client socket
;; using sys_write
_echo:
    mov     rax, 1               ; SYS_WRITE
    mov     rdi, [sock]        ; client socket fd
    mov     rsi, echobuf         ; buffer
    mov     rdx, [read_count]        ; read 256 bytes
    ; mov     rdx, 256    ; number of bytes received in _read
    syscall

    ret

;; Performs sys_close on the socket in rdi
_close_sock:
    mov     rax, 3        ; SYS_CLOSE
    syscall

    ret

;; Error Handling code
;; _*_fail loads the rsi and rdx registers with the appropriate
;; error messages for given system call. Then call _fail to display the
;; error message and exit the application.
_socket_fail:
    mov     rsi, sock_err_msg
    mov     rdx, sock_err_msg_len
    call    _fail

_connect_fail:
    mov     rsi, connect_err_msg
    mov     rdx, connect_err_msg_len
    call    _fail

;; Calls the sys_write syscall, writing an error message to stderr, then exits
;; the application. rsi and rdx must be loaded with the error message and
;; length of the error message before calling _fail
_fail:
    mov        rax, 1 ; SYS_WRITE
    mov        rdi, 2 ; STDERR
    syscall

    mov        rdi, 1
    call       _exit

;; Exits cleanly, checking if the listening or client sockets need to be closed
;; before calling sys_exit
_exit:
    mov        rax, [sock]
    cmp        rax, 0
    je         .server_check
    mov        rdi, [sock]
    call       _close_sock

    .server_check:
    mov        rax, [server]
    cmp        rax, 0
    je         .perform_exit
    mov        rdi, [server]
    call       _close_sock

    .perform_exit:
    mov        rax, 60
    syscall

_get_ip:
    mov rax, 1
    mov rdi, 1
    mov rsi, ip_msg
    mov rdx, ip_msg_len
    syscall

    mov rax, 0
    mov rdi, 0
    mov rsi, ipaddr
    mov rdx, 256
    syscall

    ret

_get_msg:
    mov rax, 1
    mov rdi, 1
    mov rsi, client_prompt
    mov rdx, client_prompt_len
    syscall

    mov       rax, 0             ; SYS_WRITE
    mov       rdi, 0             ; STDOUT
    mov       rsi, echobuf
    mov       rdx, 256
    syscall

    mov [read_count], rax

    ret
