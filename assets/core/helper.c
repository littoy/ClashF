#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <command_string>\n", argv[0]);
        return 1;
    }

    // Elevate privileges
    if (setuid(0) != 0) {
        perror("setuid failed");
        return 1;
    }
    
    // Also set gid to root to be sure
    if (setgid(0) != 0) {
        // Warning only, as setuid is the most important
        // perror("setgid failed");
    }

    char *cmd = argv[1];
    
    // Use bash -p to preserve privileges since /bin/sh (bash) might drop them
    execl("/bin/bash", "bash", "-p", "-c", cmd, (char *)0);

    perror("exec failed");
    return 1;
}
