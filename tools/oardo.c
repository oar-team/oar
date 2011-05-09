/*
 * This wrapper is used to execute user commands with oar privileges.
 * The executable must:
 *      chown root:root xxxxxxxx
 *      chmod +s xxxxxxxx
 */

///////////////////////////////////////////////////////////////////////////////
// Static conf to edit //
/////////////////////////

#define CMD_WRAPPER "/usr/local/oar/oarsub"

#define OARDIR "/usr/local/oar"
#define OARCONFFILE "/etc/oar/oar.conf"
#define OARXAUTHLOCATION "/usr/bin/xauth"
#define USERTOBECOME "root"

///////////////////////////////////////////////////////////////////////////////

#include <stdlib.h>
#include <sys/types.h>
#include <pwd.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>

// Print on stderr a string and exit with the given exit code
void error(char *error_str, int exit_code){
    fprintf(stderr, "[OARDO] ERROR: %s (%s)\n", error_str, strerror(errno));
    exit(exit_code);
}

int main(int ac, char **av){
    struct passwd *passwd_user_pointer;
    struct passwd *passwd_oar_user_pointer;
    char str_tmp[256];

    // Get user information: effective user and oar
    passwd_user_pointer = getpwuid(getuid());
    if (passwd_user_pointer == NULL){
        error("Cannot get current user information", 2);
    }
    passwd_oar_user_pointer = getpwnam(USERTOBECOME);
    if (passwd_oar_user_pointer == NULL){
        error("Cannot get oar user information", 2);
    }

    // Set right environment variables
    if (setenv("OARDO_USER", passwd_user_pointer->pw_name, 1)){
        error("Cannot change environment variable OARDO_USER", 2);
    }
    if (setenv("OARDIR", OARDIR, 1)){
        error("Cannot change environment variable OARDIR", 2);
    }
    sprintf(str_tmp, "%i", passwd_user_pointer->pw_uid);
    if (setenv("OARDO_UID", str_tmp, 1)){
        error("Cannot change environment variable OARDO_UID", 2);
    }
    if (setenv("PERL5LIB", OARDIR, 1)){
        error("Cannot change environment variable PERL5LIB", 2);
    }
    if (setenv("RUBYLIB", OARDIR, 1)){
        error("Cannot change environment variable RUBYLIB", 2);
    }
    if (setenv("OARCONFFILE", OARCONFFILE, 1)){
        error("Cannot change environment variable OARCONFFILE", 2);
    }
    if (setenv("OARXAUTHLOCATION", OARXAUTHLOCATION, 1)){
        error("Cannot change environment variable OARXAUTHLOCATION", 2);
    }

    // Clean some environment variables
    if (setenv("PATH", "/bin:/sbin:/usr/bin:/usr/sbin:"OARDIR"/../bin:"OARDIR"/../sbin:"OARDIR"/oardodo", 1)){
        error("Cannot change environment variable PATH", 2);
    }
    if (unsetenv("IFS")){
        error("Cannot unset environment variable IFS", 2);
    }
    if (unsetenv("CDPATH")){
        error("Cannot unset environment variable CDPATH", 2);
    }
    if (unsetenv("MAIL")){
        error("Cannot unset environment variable MAIL", 2);
    }
    if (unsetenv("ENV")){
        error("Cannot unset environment variable ENV", 2);
    }
    if (unsetenv("BASH_ENV")){
        error("Cannot unset environment variable BASH_ENV", 2);
    }
    if (unsetenv("LD_LIBRARY_PATH")){
        error("Cannot unset environment variable LD_LIBRARY_PATH", 2);
    }
    
    // Become oar
    if (setgid(passwd_oar_user_pointer->pw_gid)){
        error("Cannot setgid with oar gid", 2);
    }
    if (setuid(passwd_oar_user_pointer->pw_uid)){
        error("Cannot setuid with oar uid", 2);
    }

    // Set environment variables to match the new oar user ownership
    if (setenv("USER", passwd_oar_user_pointer->pw_name, 1)){
        error("Cannot change environment variable USER", 2);
    }
    if (setenv("OARUSER", passwd_oar_user_pointer->pw_name, 1)){
        error("Cannot change environment variable OARUSER", 2);
    }
    if (setenv("LOGNAME", passwd_oar_user_pointer->pw_name, 1)){
        error("Cannot change environment variable LOGNAME", 2);
    }
    if (setenv("SHELL", passwd_oar_user_pointer->pw_shell, 1)){
        error("Cannot change environment variable SHELL", 2);
    }
    if (setenv("HOME", passwd_oar_user_pointer->pw_dir, 1)){
        error("Cannot change environment variable HOME", 2);
    }

    // execute the OAR command with oar privileges
    execv(CMD_WRAPPER, av);
    error("Cannot run with oar privileges "CMD_WRAPPER, 1);
}

