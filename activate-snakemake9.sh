#!/bin/bash
# One-shot environment activation for the Snakemake 9 + HTCondor-plugin path.
#
# lxplus doesn't persist `source` across new logins/nodes, and this project
# needs a newer Python than the system default (3.9) to run Snakemake >=9,
# so both pieces have to be re-sourced together each session. Usage:
#   source activate-snakemake9.sh
LCG_VIEW=/cvmfs/sft.cern.ch/lcg/views/LCG_110/x86_64-el9-gcc13-opt/setup.sh
VENV=/eos/home-k/kfilonen/venvs/snakemake9

if [ ! -f "$LCG_VIEW" ]; then
    echo "LCG view not found at $LCG_VIEW -- check available releases under /cvmfs/sft.cern.ch/lcg/views/" >&2
    return 1 2>/dev/null || exit 1
fi
source "$LCG_VIEW"

if [ ! -f "$VENV/bin/activate" ]; then
    echo "venv not found at $VENV -- create it first:" >&2
    echo "  python3 -m venv $VENV" >&2
    echo "  source $VENV/bin/activate" >&2
    echo "  pip install \"snakemake>=9,<10\" snakemake-executor-plugin-htcondor python-htcondor" >&2
    return 1 2>/dev/null || exit 1
fi
source "$VENV/bin/activate"

python3 --version
snakemake --version
