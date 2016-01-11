#!/usr/bin/env python
# OAR API helper to extract colmet data of a given job
# from hdf5 timestamped files
# Output: json
# Usage is:
# colmet_extract.py <path_prefix> <id> <start_timestamp> <end_timestamp> <coma_separated_list_of_metrics> <json|yaml>
#

import sys
import h5py
import glob
import numpy as np
import json
import gzip

# Check args
if len(sys.argv) != 6:
    print "Usage:"
    print sys.argv[0]+" <colmet_hdf5_path_prefix> <id> <start_timestamp> <end_timestamp> <coma_sep_metrics>"
    exit(1)

colmet_hdf5_files_path_prefix=sys.argv[1]
job_id=sys.argv[2]
start=int(sys.argv[3])
stop=int(sys.argv[4])
metrics=sys.argv[5].split(',')
metrics.extend(['timestamp','hostname'])

# Get file list and timestamps intervals
files=glob.glob(colmet_hdf5_files_path_prefix+"."+"[0-9]"*10+".hdf5")
if files==[]:
    sys.stderr.write("No "+colmet_hdf5_files_path_prefix+".<timestamp>.hdf5 file found!\n")
    exit(2)
timestamps=sorted([ int(f.split('.')[1]) for f in files ])
intervals=zip(timestamps[:-1],timestamps[1:])
intervals.append((timestamps[-1],9999999999))

# HDF5 files parsing
output_metrics={}
for interval in intervals:
    if start < interval[1] and stop >= interval[0]:
        f = h5py.File(colmet_hdf5_files_path_prefix+"."+str(interval[0])+".hdf5")
        m = 'job_'+job_id+'/metrics'
        if m in f:
            for metric in metrics:
              if metric in output_metrics.keys():
                  output_metrics[metric].extend(f[m][metric].tolist())
              else:
                  output_metrics[metric]=f[m][metric].tolist()

# Empty case
if not "timestamp" in output_metrics.keys():
    sys.stderr.write("No data found\n")
    exit(4)

# Generating output
f = gzip.open('/dev/stdout', 'wb')
f.write(json.dumps(output_metrics))
f.close()
