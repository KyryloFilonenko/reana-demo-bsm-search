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
#
# The plugin hands this wrapper the complete, already-assembled command
# (python path, -m snakemake, and the real job args) as arguments -- it
# doesn't strip anything for us here, so just re-exec verbatim rather than
# building a new "python3 -m snakemake ..." command (that would duplicate
# -m snakemake and break argument parsing).
#
# The plugin also never sets HTCondor's initialdir, so without this the job
# runs in HTCondor's own scratch directory on the worker: the rule's shell
# command still succeeds (ExitCode 0), but Snakemake can't find the
# relative-path outputs afterwards ("parent dir not present"). Trying to fix
# this via the htcondor_submit_initialdir resource hit the same auto-quoting
# bug as should_transfer_files/requirements (embeds literal quote characters
# into the path), so just cd here instead, where we control the value.
cd /afs/cern.ch/user/k/kfilonen/reana-demo-bsm-search || exit 1
exec "$@"
