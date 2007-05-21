#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * $Id$
 * This is a program to parse the option passed to openssh ssh command.
 * This is a barely stipped version of file ssh.c from source tree of openssh.
 */

/*
 * Name of the host we are connecting to.  This is the name given on the
 * command line, or the HostName specified for the user-supplied name in a
 * configuration file.
 */
char *host;

static void
usage(void)
{
	fprintf(stderr,
"usage: ssh [-1246AaCfgkMNnqsTtVvXxY] [-b bind_address] [-c cipher_spec]\n"
"           [-D [bind_address:]port] [-e escape_char] [-F configfile]\n"
"           [-i identity_file] [-L [bind_address:]port:host:hostport]\n"
"           [-l login_name] [-m mac_spec] [-O ctl_cmd] [-o option] [-p port]\n"
"           [-R [bind_address:]port:host:hostport] [-S ctl_path]\n"
"           [-w local_tun[:remote_tun]] [user@]hostname [command]\n"
	);
	exit(255);
}

/*
 * Main program for the ssh client.
 */
int
main(int ac, char **av)
{
	int i, opt;
	char *p, *cp;
	extern int optind;
	extern char *optarg;

	/* Parse command-line arguments. */
	host = NULL;

	i=0;
 again:
	while ((opt = getopt(ac, av,
	    "1246ab:c:e:fgi:kl:m:no:p:qstvxACD:F:I:L:MNO:PR:S:TVw:XY")) != -1) {
		switch (opt) {
		case '1':
		case '2':
		case '4':
		case '6':
		case 'n':
		case 'f':
		case 'x':
		case 'X':
		case 'Y':
		case 'g':
		case 'P':	/* deprecated */
		case 'a':
		case 'A':
		case 'k':
		case 't':
		case 'v':
		case 'V':
		case 'q':
		case 'M':
		case 's':
		case 'T':
		case 'N':
		case 'C':
			printf("OPT[%i]=-%c\n", i++, opt);
			break;
		case 'O':
		case 'i':
		case 'I':
		case 'w':
		case 'e':
		case 'c':
		case 'm':
		case 'p':
		case 'l':
		case 'L':
		case 'R':
		case 'D':
		case 'o':
		case 'S':
		case 'b':
		case 'F':
			printf("OPT[%i]=-%c %s\n", i++, opt, optarg);
			break;
		default:
			usage();
		}
	}

	ac -= optind;
	av += optind;

	if (ac > 0 && !host && **av != '-') {
		if (strrchr(*av, '@')) {
			p = strdup(*av);
			cp = strrchr(p, '@');
			if (cp == NULL || cp == p)
				usage();
			*cp = '\0';
			printf("USER=%s\n", p);
			host = ++cp;
		} else
			host = *av;
		if (ac > 1) {
			optind = optreset = 1;
			goto again;
		}
		ac--, av++;
	}

	/* Check that we got a host name. */
	if (!host)
		usage();

	printf("HOST=%s\n", host);

	printf("COMMAND=");
	/* Is a command specified ? */
	if (ac) {
		for (i = 0; i < ac; i++) {
			if (i)
				printf(" ");
			printf("%s",av[i]);
		}
	}
	printf("\n");

	return 0;
}

