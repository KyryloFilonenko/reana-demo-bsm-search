#!/bin/bash
# One-shot environment setup for the pixi-based Snakemake 9 + HTCondor-plugin
# path (self-contained conda env, unlike the venv path in
# activate-snakemake9.sh, which turned out not to be portable enough for
# HTCondor's EosSubmit file-transfer execution model). Usage:
#   source activate-pixi.sh
#
# From here on, always run snakemake as `pixi run snakemake ...`, never a
# bare `snakemake ...` -- a bare call picks up whatever's on PATH (often the
# old venv), which silently reintroduces the exact bootstrap failure this
# path exists to avoid.

# pixi's own cache (repodata, pypi-mapping, etc.) and Snakemake's internal
# runtime cache both default to $HOME/.cache, which is AFS and chronically
# out of quota.
export XDG_CACHE_HOME=/eos/home-k/kfilonen/.cache
mkdir -p "$XDG_CACHE_HOME"

# pixi itself lives on EOS (installed there for the same AFS-quota reason).
export PIXI_HOME=/eos/home-k/kfilonen/.pixi
export PATH="$PIXI_HOME/bin:$PATH"

# The project checkout and HTCondor job I/O live on EOS; the standard schedd
# rejects /eos paths in submit files outright, so submission has to go
# through the EOS-aware schedd instead.
module load lxbatch/eossubmit

pixi --version
