/*
 *  This executable must:
 *      chown root:oar xxxxxxxx
 *      chmod 750 xxxxxxxx
 *      chmod +s xxxxxxxx
 *
 *  Cases for the use of this wrapper:
 *  
 *      - The user OARUSER executes this wrapper and OARDO_BECOME_USER is empty
 *          --> if ARGV is empty
 *                  then run the root shell with a dash in front of the process
 *                  name (login shell)
 *              else
 *                  ARGV is executed with root privileges
 *
 *      - The user OARUSER executes this wrapper and OARDO_BECOME_USER is set
 *          --> if ARGV is empty
 *                  then run the OARDO_BECOME_USER shell with a dash in front of
 *                  the process name (login shell)
 *              else
 *                  if OARDO_USE_USER_SHELL is set
 *                      then execute "shell ARGV" with OARDO_BECOME_USER
 *                      privileges and the user shell
 *                  else
 *                      ARGV is executed with OARDO_BECOME_USER privileges
 */ 

///////////////////////////////////////////////////////////////////////////////
// Static conf to edit //
/////////////////////////

#define OARDIR "TT/usr/local/oar"
#define OARCONFFILE "TT/etc/oar/oar.conf"
#define OARXAUTHLOCATION "TT/usr/bin/xauth"
#define OARUSER "TToar"

///////////////////////////////////////////////////////////////////////////////

#define DEFAULTUSERTOBECOME "root"
#define MAX_NB_SECONDARY_GROUPS 65536

#include <stdlib.h>
#include <sys/types.h>
#include <pwd.h>
#include <unistd.h>
#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <grp.h>

// Print on stderr a string and exit with the given exit code
void error(char *error_str, int exit_code){
    fprintf(stderr, "[OARDODO] ERROR: %s (%s)\n", error_str, strerror(errno));
    exit(exit_code);
}

int main(int ac, char **av){
    struct passwd *passwd_initial_user_pointer;
    struct passwd *passwd_user_to_become_pointer;
    char *user_to_become;

    // Get user information: effective user
    passwd_initial_user_pointer = getpwuid(getuid());
    if (passwd_initial_user_pointer == NULL){
        error("Cannot get current user information", 52);
    }

    // Set right environment variables
    if (setenv("OARDO_USER", passwd_initial_user_pointer->pw_name, 1)){
        error("Cannot change environment variable OARDO_USER", 52);
    }
    char str_tmp[256];
    sprintf(str_tmp, "%i", passwd_initial_user_pointer->pw_uid);
    if (setenv("OARDO_UID", str_tmp, 1)){
        error("Cannot change environment variable OARDO_UID", 52);
    }
    if (setenv("OARDIR", OARDIR, 1)){
        error("Cannot change environment variable OARDIR", 52);
    }
    if (setenv("PERL5LIB", OARDIR, 1)){
        error("Cannot change environment variable PERL5LIB", 52);
    }
    if (setenv("OARUSER", OARUSER, 1)){
        error("Cannot change environment variable OARUSER", 52);
    }
    if (setenv("OARXAUTHLOCATION", OARXAUTHLOCATION, 1)){
        error("Cannot change environment variable OARXAUTHLOCATION", 52);
    }
    if (setenv("OARCONFFILE", OARCONFFILE, 1)){
        error("Cannot change environment variable OARCONFFILE", 52);
    }

    // Clean some environment variables
    if (unsetenv("IFS")){
        error("Cannot unset environment variable IFS", 52);
    }
    if (unsetenv("CDPATH")){
        error("Cannot unset environment variable CDPATH", 52);
    }
    if (unsetenv("MAIL")){
        error("Cannot unset environment variable MAIL", 52);
    }
    if (unsetenv("LD_LIBRARY_PATH")){
        error("Cannot unset environment variable LD_LIBRARY_PATH", 52);
    }
    
    // Check if we become root or a specific user
    if ((getenv("OARDO_BECOME_USER") != NULL) && (strlen(getenv("OARDO_BECOME_USER")) > 0)){
        user_to_become = getenv("OARDO_BECOME_USER");
        if (unsetenv("OARDO_BECOME_USER")){
            error("Cannot unset environment variable OARDO_BECOME_USER", 52);
        }
    }else{
        user_to_become = DEFAULTUSERTOBECOME;
    }

    // Tell OOM to kill the user processes first except for root and oar
    if ( (strcmp(user_to_become, "root") != 0) && (strcmp(user_to_become, OARUSER) != 0) ){
        FILE *oom_file;
        if ((oom_file = fopen("/proc/self/oom_score_adj", "w")) != NULL){
            fprintf(oom_file, "1000");
            fclose(oom_file);
        }else{
            if ((oom_file = fopen("/proc/self/oom_adj", "w")) != NULL){
                fprintf(oom_file, "15");
                fclose(oom_file);
            }
        }
    }

    // Change process owner
    passwd_user_to_become_pointer = getpwnam(user_to_become);
    if (passwd_user_to_become_pointer == NULL){
        error("Cannot get user to become information", 52);
    }
    // Get the whole list of groups
    gid_t secondary_groups[MAX_NB_SECONDARY_GROUPS];
    int ngroups = MAX_NB_SECONDARY_GROUPS;
    if (getgrouplist(user_to_become, passwd_user_to_become_pointer->pw_gid, secondary_groups, &ngroups) == -1) {
        error("Cannot get secondary groups", 52);
    }
    if (setgid(passwd_user_to_become_pointer->pw_gid)){
        error("Cannot setgid", 52);
    }
    if (setgroups(ngroups, secondary_groups)){
        error("Cannot setgroups", 52);
    }
    if (setuid(passwd_user_to_become_pointer->pw_uid)){
        error("Cannot setuid", 52);
    }

    // Set new owner env variables
    if (setenv("USER", passwd_user_to_become_pointer->pw_name, 1)){
        error("Cannot change environment variable USER", 52);
    }
    if (setenv("LOGNAME", passwd_user_to_become_pointer->pw_name, 1)){
        error("Cannot change environment variable LOGNAME", 52);
    }
    if (setenv("SHELL", passwd_user_to_become_pointer->pw_shell, 1)){
        error("Cannot change environment variable SHELL", 52);
    }
    if (setenv("HOME", passwd_user_to_become_pointer->pw_dir, 1)){
        error("Cannot change environment variable HOME", 52);
    }

    if (ac <= 1){
        // Login shell
        if (chdir(passwd_user_to_become_pointer->pw_dir)){
            error("Cannot go to the home directory of the user to become", 52);
        }
        // First argument of the shell is - so it is a login shell
        execl(passwd_user_to_become_pointer->pw_shell, "-oardodo", NULL);
        error("Cannot run a login shell", 51);
    }else{
        if ((getenv("OARDO_USE_USER_SHELL") != NULL) && (strlen(getenv("OARDO_USE_USER_SHELL")) > 0)){
            if (unsetenv("OARDO_USE_USER_SHELL")){
                error("Cannot unset environment variable OARDO_USE_USER_SHELL", 52);
            }
            if (chdir(passwd_user_to_become_pointer->pw_dir)){
                error("Cannot go to the home directory of the user to become", 52);
            }
            // Execute the command with  the user's shell like '/bin/sh -c'
            av[0] = passwd_user_to_become_pointer->pw_shell;
            
            execv(passwd_user_to_become_pointer->pw_shell, av);
            error("Cannot run the command with the shell of the user", 51);
        }else{
            // Ececute the rest of the command line without passing by the
            // shell of the user
            av = &av[1];
            ac--;
            // execvp will search through the current PATH
            execvp(av[0], av);
            error("Cannot run the command", 52);
        }
    }
}

