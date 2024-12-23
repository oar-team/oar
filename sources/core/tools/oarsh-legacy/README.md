OARSH
=====
`oarsh` is the connector of OAR, that can be used in place of `ssh` in order to connect to reserved nodes.

oarsh and oarsh_shell
---------------------
`oarsh` overloads `ssh`, with the same command line options.

`oarsh` underneath connects to nodes using the oar user via `ssh` (port `6667`).

The oar user uses a special shell called `oarsh_shell`, that does the OAR machinery.

`oarsh` will place the processes it creates in the job's cgroup.

`oarsh` also supports "sub-jobs" or "tasks", allowing partitioning the job resources in smaller sets to execute on, e.g. per core or GPU while in a job containing several cores or GPUs. This is achieved using the `OAR_USER_CPUSET` and `OAR_USER_GPUDEVICE` environment variables

One can alias or symlink `ssh` to `oarsh` (e.g. '~/bin/ssh -> /usb/bin/oarsh'), in order to use `oarsh` as `ssh` seamlessly.

`oarsh_shell` is also used by `oarsub` when creating an interactive job.

ssh and PAM
-----------

PAM can be configured to have users' `ssh` (real `ssh`, not via `oarsh`) connect nodes and place the created processes in the job's cgroup.

This uses `pam_exec.so` with the `pam_oar_adopt` script

If a user reserved a node, PAM will find out the job's cgroup and place the process in it. It will also load the job's environment variables.

If a user tries to connect to a node that he did not reserve or reserved multiple times (e.g. 2 different jobs reserving each a subset of the node's cores), nothing will be done (`ssh` may fail if configured so via `pam_access.so`).

### PAM configuration example (debian):

#### `/etc/pam.d/common-account`
```
account sufficient      pam_exec.so quiet debug stdout /usr/sbin/pam_oar_adopt -a
account sufficient      pam_access.so accessfile=/etc/security/access.conf
account required        pam_access.so accessfile=/var/lib/oar/access.conf

account sufficient      pam_ldap.so
account required        pam_unix.so
```

#### `cat common-session`
```
# here are the per-package modules (the "Primary" block)
session [default=1]                     pam_permit.so
# here's the fallback if no module succeeds
session requisite                       pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
session required                        pam_permit.so
# and here are more per-package modules (the "Additional" block)
session required        pam_unix.so
session [success=ok default=ignore]     pam_ldap.so minimum_uid=1000
session optional        pam_systemd.so
session required   pam_exec.so stdout /usr/local/sbin/pam_oar_adopt -s
session optional   pam_env.so readenv=1 envfile=/var/lib/oar/pam.env
```

#### `common-session-noninteractive`
```
# here are the per-package modules (the "Primary" block)
session [default=1]                     pam_permit.so
# here's the fallback if no module succeeds
session requisite                       pam_deny.so
# prime the stack with a positive return value if there isn't one already;
# this avoids us returning an error just because nothing sets a success code
# since the modules above will each just jump around
session required                        pam_permit.so
# and here are more per-package modules (the "Additional" block)
session required        pam_unix.so
session [success=ok default=ignore]     pam_ldap.so minimum_uid=1000
session required   pam_exec.so seteuid stdout /usr/local/sbin/pam_oar_adopt -s
session optional   pam_env.so readenv=1 envfile=/var/lib/oar/pam.env
```
