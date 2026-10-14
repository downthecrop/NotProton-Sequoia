// Spawns argv[1] the way the client spawns its port check, through posix_spawn with its
// own environment. Named steam_osx or Steam Helper by the make target so the dylib
// installs its hooks.
#include <spawn.h>
#include <sys/wait.h>
extern char **environ;
int main(int argc, char **argv) {
    if (argc < 2) return 2;
    char *a[] = { argv[1], NULL };
    pid_t pid;
    int st = 0;
    if (posix_spawn(&pid, argv[1], NULL, NULL, a, environ) != 0) return 111;
    waitpid(pid, &st, 0);
    return 0;
}
