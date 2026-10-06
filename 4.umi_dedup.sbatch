#!/bin/bash
#SBATCH -J umi_dedup
#SBATCH --partition=rhel_short
#SBATCH --time=0-8:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --array=0-75
#SBATCH -o logs/umi_dedup_%A_%a.out
#SBATCH -e logs/umi_dedup_%A_%a.err
#SBATCH --mail-type=FAIL

set -euo pipefail

############## software ##############

#   mamba activate quantseq
#
module load samtools || true

# Fail immediately and legibly if umi_tools is not actually on PATH
if ! command -v umi_tools >/dev/null 2>&1; then
    echo "ERROR: umi_tools not found on PATH."
    echo "Edit the 'software' block at the top of this script to load it correctly."
    exit 1
fi

############## directory hierarchy ##############

PROJECT_DIR="/scratch/users/nbartonicek/projects/ben_legg"

IN_DIR="${PROJECT_DIR}/results/star"
OUT_DIR="${PROJECT_DIR}/results/dedup"

mkdir -p "${OUT_DIR}" logs

############## input file list ##############

# Genome BAMs only. STAR also wrote *.Aligned.toTranscriptome.out.bam per
# sample; umi_tools must not be pointed at those, because a read maps to many
# overlapping transcripts there and duplicate collapsing becomes meaningless.
mapfile -t BAMS < <(
    find "${IN_DIR}" \
        -mindepth 2 -maxdepth 2 \
        -type f \
        -name "*.Aligned.sortedByCoord.out.bam" | \
    sort
)

if [[ ${#BAMS[@]} -eq 0 ]]; then
    echo "ERROR: No genome BAM files found under ${IN_DIR}"
    exit 1
fi

if [[ ${SLURM_ARRAY_TASK_ID} -ge ${#BAMS[@]} ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID ${SLURM_ARRAY_TASK_ID} exceeds BAM count ${#BAMS[@]}"
    exit 1
fi

BAM="${BAMS[$SLURM_ARRAY_TASK_ID]}"
BASE=$(basename "${BAM}" .Aligned.sortedByCoord.out.bam)

SAMPLE_OUT_DIR="${OUT_DIR}/${BASE}"
mkdir -p "${SAMPLE_OUT_DIR}"

OUT_BAM="${SAMPLE_OUT_DIR}/${BASE}.dedup.bam"

echo "========================================"
echo "Sample:     ${BASE}"
echo "Input BAM:  ${BAM}"
echo "Output BAM: ${OUT_BAM}"
echo "========================================"

# The BAM index is required by umi_tools; 3.star.sbatch makes it, but a BAM
# copied or moved by hand may have lost it.
if [[ ! -s "${BAM}.bai" ]]; then
    echo "BAM index missing, creating it..."
    samtools index "${BAM}"
fi

############## UMI deduplication ##############

# These reads carry a 14 bp UMI appended to the read name with an underscore,
# e.g. @LH01042:177:23LM25LT3:7:1101:3559:1045_GTTACGTTGAACCA. That is the
# layout umi_tools itself writes, so it is read back with the defaults:
#   --extract-umi-method=read_id  (UMI lives in the read name)
#   --umi-separator="_"           (text after the last underscore is the UMI)
# Both are stated explicitly rather than relied on, so the script keeps working
# if a future umi_tools release changes its defaults.
#
# --method=directional is the umi_tools default and the right choice here: it
# collapses UMIs that differ by sequencing error into the parent UMI, instead
# of treating every 1 bp variant as an independent molecule. With a 14 bp UMI
# the space is large enough that genuine collisions are rare.
#
# Single-end data, so no --paired.
umi_tools dedup \
    --stdin="${BAM}" \
    --stdout="${OUT_BAM}" \
    --extract-umi-method=read_id \
    --umi-separator="_" \
    --method=directional \
    --log="${SAMPLE_OUT_DIR}/${BASE}.dedup.log"

if [[ ! -s "${OUT_BAM}" ]]; then
    echo "ERROR: deduplicated BAM not produced: ${OUT_BAM}"
    exit 1
fi

samtools index "${OUT_BAM}"

# Retention rate is the number worth eyeballing across samples: a very low
# value means the library was sequenced far past its complexity.
echo "--- read counts before/after dedup ---"
before=$(samtools view -c "${BAM}")
after=$(samtools view -c "${OUT_BAM}")
echo "before: ${before}"
echo "after:  ${after}"
awk -v b="${before}" -v a="${after}" 'BEGIN{ if(b>0) printf "retained: %.1f%%\n", 100*a/b }'

echo "Done: ${BASE}"
