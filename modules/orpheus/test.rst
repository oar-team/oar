
sudo -u oar oarnodesetting -h node2 -s "Alive"
sudo -u oar oarnodesetting -h node3 -s "Alive"

oarsub plop
oarsub "plop {exec_time=20}"
oarsub "plop {exec_time=10,io=1,io_workload=1}" OK
oarsub "plop {exec_time=10,io=1,io_workload=10}" OK

oarsub "plop {exec_time=10,io=1,io_workload=20}" OK

test: multiple
oarsub "plop {exec_time=10,io=1,io_workload=5}" &
oarsub "plop {exec_time=10,io=1,io_workload=5}" &
10sec

oarsub "plop {exec_time=10,io=1,io_workload=10}" &
oarsub "plop {exec_time=10,io=1,io_workload=10}" &
20sec


oarsub "plop {exec_time=10,io=1,io_workload=10}" &
oarsub "plop {exec_time=10,io=1,io_workload=10}" &
oarsub "plop {exec_time=10}" &
20-20-10


oarsub "plop {exec_time=30,io=1,io_workload=10}" &
sleep 5; oarsub "plop {exec_time=10,io=1,io_workload=10}"
40-20 -> OK


-- test if old already terminated io_job is not counted again
oarsub "plop {exec_time=20,io=1,io_workload=10}";
sleep 5; oarsub "plop {exec_time=5,io=1,io_workload=10}";
sleep 25; oarsub "plop {exec_time=10,io=1,io_workload=10}";
=========================================================================
nb_jobs launched: 3 terminated:   3 running:  0
nb_recv_signal/nb_get_jobs  3 3 
io_workload:  0
=========================================================================



