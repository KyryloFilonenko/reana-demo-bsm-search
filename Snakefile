# Snakemake port of workflow/databkgmc.yml (reana-demo-bsm-search)
#
# Local dry-run:   snakemake -np
# Local run:       snakemake --cores 4 --software-deployment-method apptainer
# Quick test run:  snakemake --cores 4 --software-deployment-method apptainer \
#                    --config profile=test
# On REANA:        reana-client validate -f reana-snakemake.yaml && ...

# ---------------------------------------------------------------------------
# Configuration (full = numbers from databkgmc.yml, test = small local run)
# ---------------------------------------------------------------------------
PROFILES = {
    "full": {
        "batches":  {"data": 5,     "sig": 2,     "mc1": 4,     "mc2": 4},
        "nevents":  {"data": 20000, "sig": 40000, "mc1": 40000, "mc2": 40000},
        "mc_weights": {"mc1": 0.01875, "mc2": 0.0125},
        "sig_weight": 0.0025,
    },
    "test": {
        "batches":  {"data": 10,    "sig": 4,    "mc1": 2,   "mc2": 2},
        "nevents":  {"data": 10000, "sig": 1000, "mc1": 200, "mc2": 200},
        "mc_weights": {"mc1": 0.01875, "mc2": 0.0125},
        "sig_weight": 0.02,
    },
}

PROFILE = config.get("profile", "full")
CFG = PROFILES[PROFILE]

BATCHES    = CFG["batches"]
NEVENTS    = CFG["nevents"]
MC_WEIGHTS = CFG["mc_weights"]
SIG_WEIGHT = CFG["sig_weight"]

MC_SAMPLES = ["mc1", "mc2"]
QCD_WEIGHT = 0.1875  # 0.2 / 0.8 * 0.75 transfer factor to signal region

WEIGHT_VARIATIONS = "nominal,weight_var1_up,weight_var1_dn"
SHAPE_VARS = ["shape_conv_up", "shape_conv_dn"]

# Reproducibility: deterministic, per-job-unique seeds.
# Requires the generantuple.py patch (extra CLI argument + random.seed).
BASE_SEED = 42
SEED_OFFSET = {"data": 0, "sig": 100, "mc1": 200, "mc2": 300}

IMG_MAIN  = "docker://docker.io/reanahub/reana-demo-bsm-search:1.0.0"
IMG_ROOT6 = "docker://docker.io/reanahub/reana-env-root6:6.18.04"

ROOTENV = "source /usr/local/bin/thisroot.sh && "


wildcard_constraints:
    sample="data|sig|mc1|mc2",
    mc="mc1|mc2",
    region="signal|control",
    shapevar="shape_.+",
    b=r"\d+",


rule all:
    input:
        "plot/prefit.pdf",
        "plot/postfit.pdf",
        "hepdata/submission.zip",


# ---------------------------------------------------------------------------
# Generation (shared by all samples; Yadage stage "read" in each branch)
# ---------------------------------------------------------------------------
_GEN_CASE = "\n".join(
    f"          {s}) nevents={NEVENTS[s]}; offset={SEED_OFFSET[s]} ;;"
    for s in ["data", "sig", "mc1", "mc2"]
)


rule generate:
    output:
        "generated/{sample}/batch_{b}.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + """
        case {wildcards.sample} in
""" + _GEN_CASE + """
        esac
        seed=$(( """ + str(BASE_SEED) + """ + offset + {wildcards.b} ))
        python /code/generantuple.py {wildcards.sample} $nevents {output} $seed
        """


rule merge_generated:
    input:
        lambda wc: expand(
            "generated/{s}/batch_{b}.root",
            s=wc.sample,
            b=range(BATCHES[wc.sample]),
        ),
    output:
        "merged/{sample}.root",
    container:
        IMG_ROOT6
    shell:
        ROOTENV + "hadd {output} {input}"


# ---------------------------------------------------------------------------
# DATA branch (workflow_data.yml): signal region + data-driven multijet (qcd)
# ---------------------------------------------------------------------------
rule data_select:
    input:
        "merged/data.root",
    output:
        "selected/data_{region}.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/select.py {input} {output} {wildcards.region} nominal"


rule data_hist_signal:
    input:
        "selected/data_signal.root",
    output:
        "hists/data_signal.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/histogram.py {input} {output} data 1.0 nominal"


rule data_hist_control:
    input:
        "selected/data_control.root",
    output:
        "hists/data_control.root",
    params:
        weight=QCD_WEIGHT,
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/histogram.py {input} {output} qcd {params.weight} nominal"


rule data_mergeall:
    input:
        "hists/data_signal.root",
        "hists/data_control.root",
    output:
        "branch/data.root",
    container:
        IMG_ROOT6
    shell:
        ROOTENV + "hadd {output} {input}"


# ---------------------------------------------------------------------------
# SIGNAL branch (workflow_sig.yml)
# ---------------------------------------------------------------------------
rule sig_select:
    input:
        "merged/sig.root",
    output:
        "selected/sig_signal.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/select.py {input} {output} signal nominal"


rule sig_hist:
    input:
        "selected/sig_signal.root",
    output:
        "branch/sig.root",
    params:
        weight=SIG_WEIGHT,
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/histogram.py {input} {output} signal {params.weight} nominal"


# ---------------------------------------------------------------------------
# MC branch (wflow_all_mc.yml -> workflow_mc.yml + workflow_select_shape.yml)
# Weight variations: one select with all weight variations, one histogram job.
# Shape variations:  one select + one histogram_shape job per variation.
# ---------------------------------------------------------------------------
rule mc_select_weights:
    input:
        "merged/{mc}.root",
    output:
        "selected/{mc}_signal_weights.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/select.py {input} {output} signal " + WEIGHT_VARIATIONS


rule mc_hist_weights:
    input:
        "selected/{mc}_signal_weights.root",
    output:
        "hists/{mc}_weights.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + """
        case {wildcards.mc} in
          mc1) weight=""" + str(MC_WEIGHTS['mc1']) + """ ;;
          mc2) weight=""" + str(MC_WEIGHTS['mc2']) + """ ;;
        esac
        python /code/histogram.py {input} {output} {wildcards.mc} $weight """ + WEIGHT_VARIATIONS


rule mc_select_shape:
    input:
        "merged/{mc}.root",
    output:
        "selected/{mc}_signal_{shapevar}.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "python /code/select.py {input} {output} signal {wildcards.shapevar}"


rule mc_hist_shape:
    input:
        "selected/{mc}_signal_{shapevar}.root",
    output:
        "hists/{mc}_{shapevar}.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + """
        case {wildcards.mc} in
          mc1) weight=""" + str(MC_WEIGHTS['mc1']) + """ ;;
          mc2) weight=""" + str(MC_WEIGHTS['mc2']) + """ ;;
        esac
        python /code/histogram.py {input} {output} """ \
        "{wildcards.mc}_{wildcards.shapevar} $weight nominal '{{name}}'"


rule mc_mergeallvars:
    input:
        "hists/{mc}_weights.root",
        expand("hists/{{mc}}_{sv}.root", sv=SHAPE_VARS),
    output:
        "branch/{mc}.root",
    container:
        IMG_ROOT6
    shell:
        ROOTENV + "hadd {output} {input}"


# ---------------------------------------------------------------------------
# Common tail: merge all branches -> workspace -> plots + HepData
# ---------------------------------------------------------------------------
rule merge_all:
    input:
        signal="branch/sig.root",
        data="branch/data.root",
        background=expand("branch/{mc}.root", mc=MC_SAMPLES),
    output:
        "merged_all/merged.root",
    container:
        IMG_ROOT6
    shell:
        ROOTENV + "hadd {output} {input.signal} {input.data} {input.background}"


rule makews:
    input:
        "merged_all/merged.root",
    output:
        "ws/workspace_combined_meas_model.root",
    container:
        IMG_MAIN
    shell:
        ROOTENV + "mkdir -p ws/xmldir && "
        "python /code/makews.py {input} ws/workspace ws/xmldir"


rule plot:
    input:
        "ws/workspace_combined_meas_model.root",
    output:
        prefit="plot/prefit.pdf",
        postfit="plot/postfit.pdf",
    container:
        IMG_MAIN
    shell:
        ROOTENV +
        "hfquickplot write-vardef {input} combined plot/nominal_vals.yml && "
        "hfquickplot plot-channel {input} combined channel1 x plot/nominal_vals.yml "
        "-c qcd,mc2,mc1,signal -o {output.prefit} && "
        "hfquickplot fit {input} combined plot/fit_results.yml && "
        "hfquickplot plot-channel {input} combined channel1 x plot/fit_results.yml "
        "-c qcd,mc2,mc1,signal -o {output.postfit}"


rule hepdata:
    input:
        "ws/workspace_combined_meas_model.root",
    output:
        "hepdata/submission.zip",
    container:
        IMG_MAIN
    shell:
        ROOTENV +
        "python /code/hepdata_export.py {input} "
        "hepdata/submission.yaml hepdata/data1.yaml && "
        "cd hepdata && zip submission.zip submission.yaml data1.yaml"
