#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/*
 * $Id$
 * This is a program to parse the option passed to openssh ssh command.
 * This is a barely stripped version of file ssh.c from source tree of openssh.
 */

static void
error(int errno)
{
	printf("SSHGETOPTS_ERROR=%i\n",errno);
	exit(errno);
}

/*
 * Main program for the ssh client.
 */
int
main(int ac, char **av)
{
	char *host;
	char *user;
	int i, opt;
	char *p, *cp;
	extern int optind;
	extern char *optarg;

	/* Parse command-line arguments. */
	host = NULL;
	user = NULL;

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
			printf("SSHGETOPTS_OPT[%i]=\"-%c\"\n", i++, opt);
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
			printf("SSHGETOPTS_OPT[%i]=\"-%c %s\"\n", i++, opt, optarg);
			break;
		default:
			error(255);
		}
	}

	ac -= optind;
	av += optind;

	if (ac > 0 && !host && **av != '-') {
		if (strrchr(*av, '@')) {
			p = strdup(*av);
			cp = strrchr(p, '@');
			if (cp == NULL || cp == p)
				error(255);
			*cp = '\0';
			user = p;
			host = ++cp;
		} else
			host = *av;
		if (ac > 1) {
			/* removing optreset which is not GNU getopt but BSD getopt. */
			/* optind = optreset = 1; */
			optind = 1;
			goto again;
		}
		ac--, av++;
	}

	/* Check that we got a host name. */
	if (!host)
		error(255);

	printf("SSHGETOPTS_OPTLAST=%i\n", i-1);
	if (user)
		printf("SSHGETOPTS_USER=\"%s\"\n", p);
	else
		printf("SSHGETOPTS_USER=\"\"\n");
	printf("SSHGETOPTS_HOST=\"%s\"\n", host);
	printf("SSHGETOPTS_COMMAND=\"");
	/* Is a command specified ? */
	if (ac) {
		for (i = 0; i < ac; i++) {
			if (i)
				printf(" ");
			printf("%s",av[i]);
		}
	}
	printf("\"\n");
	printf("SSHGETOPTS_ERROR=0\n");

	return 0;
}

