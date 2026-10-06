#!/bin/bash
#SBATCH -J featurecounts
#SBATCH --partition=rhel_short
#SBATCH --time=0-04:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=16G
#SBATCH --array=0-75
#SBATCH -o logs/featurecounts_%A_%a.out
#SBATCH -e logs/featurecounts_%A_%a.err
#SBATCH --mail-type=FAIL

set -euo pipefail

module load subread || true

############## strandedness - MUST BE SET BEFORE RUNNING ##############

# Deliberately left empty. The library chemistry for this run is not yet
# established, and guessing wrong is not a harmless error: counting a
# reverse-stranded library as forward-stranded discards most reads and the job
# still exits 0, so you get a quiet, plausible-looking, wrong result.
#
# magdalena used the equivalent of STRAND=1, but only because that was QuantSeq
# FWD. This library does not look like QuantSeq: no poly-A read-through at all
# (0.00% of reads) and 94 bp reads.
#
# Set one of:
#   0  unstranded
#   1  forward-stranded
#   2  reverse-stranded  (dUTP protocols, e.g. TruSeq Stranded mRNA)
#
# To determine it empirically, run this script once per value on a couple of
# samples and compare the "Successfully assigned alignments" percentage in the
# .summary file - the correct setting wins by a wide margin.
STRAND="1"

if [[ -z "${STRAND}" ]]; then
    echo "ERROR: STRAND is not set."
    echo "Open this script and set STRAND to 0 (unstranded), 1 (forward) or 2 (reverse)."
    echo "See the comment block above the STRAND variable for how to determine it."
    exit 1
fi

############## directory hierarchy ##############

PROJECT_DIR="/scratch/users/nbartonicek/projects/ben_legg"

BAM_DIR="${PROJECT_DIR}/results/dedup"
COUNT_DIR="${PROJECT_DIR}/results/counts/featurecounts"

mkdir -p "${COUNT_DIR}" logs

############## annotation ##############

# Plain GENCODE vM25, matching the annotation the STAR index in 3.star.sbatch
# was built from. Genes only - no RepeatMasker track.
#
# This deliberately replaces magdalena's combined gene+TE GTF. In that file the
# repeat instances are written as "exon" features with gene_id set to the repeat
# name, so with -t exon -g gene_id featureCounts treats them as genes: any read
# in a real gene exon that also overlaps a repeat annotation matches two
# gene_ids, gets marked Ambiguous, and is discarded. The loss concentrates in
# 3'UTRs, which are SINE-dense in mouse. That would be tolerable if it were
# constant across samples, but cytokine stimulation can de-repress ERVs, so the
# ambiguity rate could differ between the very groups being compared.
GTF="/team_folders/johnstone_lab/reference/indices/mm10/gencode.vM25.primary_assembly.annotation.gtf"

if [[ ! -s "${GTF}" ]]; then
    echo "ERROR: GTF not found or empty: ${GTF}"
    echo "Set GTF to a GENCODE vM25 annotation matching the STAR index used in 3.star.sbatch."
    exit 1
fi

############## input file list ##############

# Deduplicated genome BAMs from 4.umi_dedup.sbatch.
mapfile -t BAMS < <(
    find "${BAM_DIR}" \
        -mindepth 2 -maxdepth 2 \
        -type f \
        -name "*.dedup.bam" | \
    sort
)

if [[ ${#BAMS[@]} -eq 0 ]]; then
    echo "ERROR: No deduplicated BAM files found under ${BAM_DIR}"
    exit 1
fi

if [[ ${SLURM_ARRAY_TASK_ID} -ge ${#BAMS[@]} ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID (${SLURM_ARRAY_TASK_ID}) exceeds BAM count (${#BAMS[@]})"
    exit 1
fi

BAM="${BAMS[$SLURM_ARRAY_TASK_ID]}"
BASE=$(basename "${BAM}" .dedup.bam)

OUT="${COUNT_DIR}/${BASE}.featureCounts.txt"

echo "========================================"
echo "Sample: ${BASE}"
echo "Input BAM: ${BAM}"
echo "Output: ${OUT}"
echo "Strandedness (-s): ${STRAND}"
echo "GTF: ${GTF}"
echo "========================================"

# The GTF is mm10-only while the STAR index is the combined mm10_dm6 build, so
# the mouse contig names must agree between them. If they do not, featureCounts
# exits 0 having assigned almost nothing. Check the .summary file: a healthy run
# assigns roughly 60-90% of alignments, single digits means a name mismatch.

############## counting ##############

# Plain unique-read gene counting, which is what edgeR expects downstream.
# magdalena's featureCounts run used -M --fraction because that analysis was
# about transposable elements, whose reads multi-map heavily across near
# identical copies. This is an ordinary gene-level differential expression
# experiment, so multi-mappers are discarded rather than fractionally spread.
featureCounts \
    -T "${SLURM_CPUS_PER_TASK}" \
    -a "${GTF}" \
    -o "${OUT}" \
    -t exon \
    -g gene_id \
    -s "${STRAND}" \
    "${BAM}"

echo "Done: ${BASE}"
