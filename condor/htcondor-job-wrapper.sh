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
exec "$@"
