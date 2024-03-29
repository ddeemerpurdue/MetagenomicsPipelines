configfile: "config/config.yaml"

# Input only requires an assembly file.
# Config files only specifies:
1. How many assembly files there are
2. How to filter the assembly file
3 - ish. Eventually add functionality to specify how many files to split up assemblies into

# Rule to produce all ANI results from multiple samples
# The below example was tested using 8 samples, all broken into 10 parts and ran
# in a pairwise manner. This resulted in 640 parallel jobs that allowed fastANI comparisons
# across full assemblies to work in less than an hour per job.

# Script files are located under ./base_ANI_scripts/


configfile: "config/config.yaml"

# Rule to produce all ANI results from multiple samples


rule all:
    input:
        expand("split-files/{sample}/{sample}.complete.tkn",
               sample=config["assemblies"]),
        expand("lists/{sample}.{length}.txt",
               sample=config["assemblies"], length=config["length"]),
        expand("lists/{sample}.{length}_{splits}",
               sample=config["assemblies"], length=config["length"], splits=config["size"]),
        expand("output/{query}.{ref}.{length}_{split}.txt",
               query=config["assemblies"], ref=config["assemblies"], split=config["size"], length=config["length"]),
        expand("output/{query}.{reference}.{length}.all.txt",
               query=config["assemblies"], reference=config["assemblies"], length=config["length"])
        expand("output/All.{length}.txt", length=config["length"])

rule filter_contigs:
    input:
        samples = expand(
            "contigs/{sample}.contigs.fasta", sample=config["assemblies"])
    params:
        length = "5000"
    output:
        outputs = expand("filtered-contigs/{sample}.contigs.{length}.fasta",
                         sample=config["assemblies"], length=config["length"])
    script:
        "scripts/filter_contigs_sm.py"

rule split_filtered_contigs:
    input:
        samples = expand("filtered-contigs/{sample}.contigs.{length}.fasta",
                         sample=config["assemblies"], length=config["length"])
    params:
        folder = expand("split-files/{sample}", sample=config["assemblies"])
    output:
        outputs = expand(
            "split-files/{sample}/{sample}.complete.tkn", sample=config["assemblies"])
    script:
        "scripts/split.py"

rule make_contig_list:
    input:
        samples = expand(
            "split-files/{sample}/{sample}.complete.tkn", sample=config["assemblies"])
    output:
        outputs = expand("lists/{sample}.{length}.txt",
                         sample=config["assemblies"], length=config["length"])
    script:
        "scripts/makelist.py"

rule split_lists:
    input:
        samples = expand(
            "split-files/{sample}/{sample}.complete.tkn", sample=config["assemblies"]),
        lists = expand("lists/{sample}.{length}.txt",
                       sample=config["assemblies"], length=config["length"])
    output:
        outputs = expand("lists/{sample}.{length}_{splits}",
                         sample=config["assemblies"], length=config["length"], splits=config["size"])
    script:
        "scripts/splitlist.py"

rule run_fastani:
    input:
        lists = "lists/{query}.{length}.txt"
    params:
        ref = "lists/{reference}.{length}_{split}"
    output:
        outputs = "output/{query}.{reference}.{length}_{split}.txt"
    shell:
        """
        fastANI -t 20 --minFraction 0.2 --fragLen 1000 --ql {input.lists} --rl {params.ref} -o {output.outputs}
        touch output/{wildcards.query}.{wildcards.reference}.COMPLETE.tkn
        """

rule concatenate_output:
    input:
        files = directory("output")
    output:
        outputs = expand("output/All.{length}.txt", length=config["length"])
    shell:
        """
        cat {input.files}/*.txt > {output.outputs}
        """
