#!/bin/bash
# One-shot environment activation for the Snakemake 9 + HTCondor-plugin path.
#
# lxplus doesn't persist `source` across new logins/nodes, and this project
# needs a newer Python than the system default (3.9) to run Snakemake >=9,
# so both pieces have to be re-sourced together each session. Usage:
#   source activate-snakemake9.sh
LCG_VIEW=/cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-gcc13-opt/setup.sh
# Must be on AFS, not EOS: the htcondor executor plugin submits
# sys.executable (this venv's python) as the job's `executable=` attribute,
# and the standard schedd flatly rejects /eos there. AFS is mounted on the
# worker nodes too, so a thin (symlink-based) venv here works without any
# HTCondor-level transfer.
VENV=$HOME/venvs/snakemake9

# Every tool in this stack (pixi/rattler, and Snakemake's own runtime/source
# cache) defaults to $HOME/.cache, which is AFS and chronically out of
# quota. Redirect once, here, instead of chasing each tool's own cache dir
# as it turns up.
export XDG_CACHE_HOME=/eos/home-k/kfilonen/.cache
mkdir -p "$XDG_CACHE_HOME"

if [ ! -f "$LCG_VIEW" ]; then
    echo "LCG view not found at $LCG_VIEW -- check available releases under /cvmfs/sft.cern.ch/lcg/views/" >&2
    return 1 2>/dev/null || exit 1
fi
source "$LCG_VIEW"

if [ ! -f "$VENV/bin/activate" ]; then
    echo "venv not found at $VENV -- create it first:" >&2
    echo "  python3 -m venv $VENV" >&2
    echo "  source $VENV/bin/activate" >&2
    echo "  pip install \"snakemake>=9,<10\" snakemake-executor-plugin-htcondor htcondor" >&2
    return 1 2>/dev/null || exit 1
fi
source "$VENV/bin/activate"

# The venv and the project checkout both live on AFS now (see VENV comment
# above), so the standard schedd's shared-filesystem model applies -- no
# module load lxbatch/eossubmit here, and no /eos paths in job I/O.

python3 --version
snakemake --version
