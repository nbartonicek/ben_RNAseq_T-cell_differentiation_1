#!/bin/bash
#SBATCH -J star_ben_legg
#SBATCH --partition=rhel_short
#SBATCH --time=0-12:00
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --array=0-3
#SBATCH -o logs/star_%A_%a.out
#SBATCH -e logs/star_%A_%a.err
#SBATCH --mail-type=FAIL

set -euo pipefail

# Activate environment if needed
# source ~/miniconda3/etc/profile.d/conda.sh
# mamba activate star2711a

# module load star || true
export PATH="$CONDA_PREFIX/bin:$PATH"
hash -r

which STAR
STAR --version
module load samtools || true

############## directory hierarchy ##############

PROJECT_DIR="/scratch/users/nbartonicek/projects/ben_legg"

FASTQ_DIR="${PROJECT_DIR}/results/trimgalore"
OUT_DIR="${PROJECT_DIR}/results/star"

# Same combined mouse+Drosophila index magdalena used. These libraries are not
# expected to carry a dm6 spike-in; reads simply will not map to the dm6
# contigs, and nothing downstream reads them. Kept identical to magdalena on
# request, and because this index is already proven compatible with the
# GENCODE vM25 annotation used by 5.feature_counts.sbatch.
STAR_INDEX="/team_folders/johnstone_lab/reference/indices/mm10_dm6/star_gencode_vM25_100bp"

mkdir -p "${OUT_DIR}" logs

############## input file list ##############

# Trim Galore writes <sample>/<sample>_trimmed.fq.gz, hence maxdepth 2.
mapfile -t FASTQS < <(
    find "${FASTQ_DIR}" \
        -maxdepth 2 \
        -type f \
        -name "GMP5RJ*_trimmed.fq.gz" | \
    sort
)

if [[ ${#FASTQS[@]} -eq 0 ]]; then
    echo "ERROR: No trimmed FASTQs found in ${FASTQ_DIR}"
    exit 1
fi

if [[ ${SLURM_ARRAY_TASK_ID} -ge ${#FASTQS[@]} ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID ${SLURM_ARRAY_TASK_ID} exceeds FASTQ count ${#FASTQS[@]}"
    exit 1
fi

FASTQ="${FASTQS[$SLURM_ARRAY_TASK_ID]}"

BASE=$(basename "${FASTQ}")
BASE=${BASE%.fastq.gz}
BASE=${BASE%.fq.gz}

SAMPLE_OUT_DIR="${OUT_DIR}/${BASE}"
mkdir -p "${SAMPLE_OUT_DIR}"

SAMPLE_OUT_PREFIX="${SAMPLE_OUT_DIR}/${BASE}."

echo "========================================"
echo "Sample: ${BASE}"
echo "FASTQ:  ${FASTQ}"
echo "STAR index: ${STAR_INDEX}"
echo "Output prefix: ${SAMPLE_OUT_PREFIX}"
echo "========================================"

############## alignment ##############

# Single-end: one file in --readFilesIn, unchanged from magdalena.
#
# --quantMode TranscriptomeSAM is kept even though this pipeline now quantifies
# with featureCounts rather than RSEM. It costs some runtime and disk, but it
# leaves the door open to running RSEM later without re-aligning. The
# transcriptome BAM must NOT be fed to umi_tools or featureCounts - both
# downstream scripts explicitly select the genome BAM only.
STAR \
    --runMode alignReads \
    --genomeDir "${STAR_INDEX}" \
    --readFilesIn "${FASTQ}" \
    --outFileNamePrefix "${SAMPLE_OUT_PREFIX}" \
    --runThreadN "${SLURM_CPUS_PER_TASK}" \
    --outBAMsortingThreadN "${SLURM_CPUS_PER_TASK}" \
    --readFilesCommand zcat \
    --twopassMode Basic \
    --outFilterType BySJout \
    --outSAMattributes NH HI AS NM MD \
    --outFilterMultimapNmax 20 \
    --outFilterMismatchNmax 999 \
    --outFilterMismatchNoverReadLmax 0.04 \
    --twopass1readsN -1 \
    --alignEndsType Local \
    --alignSJDBoverhangMin 8 \
    --outSAMtype BAM SortedByCoordinate \
    --quantMode TranscriptomeSAM \
    --outFilterMatchNmin 40

echo "Indexing BAM..."

BAM="${SAMPLE_OUT_PREFIX}Aligned.sortedByCoord.out.bam"

if [[ ! -s "${BAM}" ]]; then
    echo "ERROR: STAR BAM not found: ${BAM}"
    exit 1
fi

# umi_tools dedup in the next step requires a coordinate-sorted, indexed BAM.
samtools index "${BAM}"

echo "Done: ${BASE}"
