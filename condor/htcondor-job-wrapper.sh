#!/bin/bash
# Used via the "job_wrapper" resource in profiles/lxbatch/profile.v9+.yaml.
#
# The htcondor executor plugin defaults to submitting sys.executable (our
# AFS venv's python, a symlink into the CVMFS LCG view) as HTCondor's own
# "executable" attribute, run directly with no shell in between. That
# crashes on the worker with "Failed to import encodings module" -- even
# though the exact same interpreter, invoked from inside a shell script
# (this file's approach), works fine and resolves AFS/CVMFS/pyvenv.cfg
# correctly. Root cause not fully pinned down; this wrapper sidesteps it.
exec /afs/cern.ch/user/k/kfilonen/venvs/snakemake9/bin/python3 -m snakemake "$@"
