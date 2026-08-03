#!/bin/bash
# Snakemake --cluster-status hook: given the cluster ID that condor/submit.sh
# printed, report exactly one of "running", "success", or "failed" so
# Snakemake knows whether to keep waiting, mark the job done, or retry/abort.
set -euo pipefail

jobid="$1"

# Still queued or running.
if condor_q "$jobid" -af JobStatus 2>/dev/null | grep -q '[0-9]'; then
    echo running
    exit 0
fi

# Left the queue: check history for how it actually exited.
exit_code=$(condor_history "$jobid" -af ExitCode 2>/dev/null | head -n1)

if [ "$exit_code" == "0" ]; then
    echo success
else
    echo failed
fi
