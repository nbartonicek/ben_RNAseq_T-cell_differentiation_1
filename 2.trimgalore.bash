#!/bin/bash
#SBATCH -J trimgalore
#SBATCH --partition=rhel_short
#SBATCH --time=0-6:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --array=0-3
#SBATCH -o logs/trimgalore_%A_%a.out
#SBATCH -e logs/trimgalore_%A_%a.err
#SBATCH --mail-type=FAIL


#mamba activate rsem

############## directory hierarchy ##############

homedir="/scratch/users/nbartonicek/projects"
project="ben_legg"
inType="trimgalore"

project_dir="${homedir}/${project}"
raw_dir="${project_dir}/raw"
out_dir="${project_dir}/results/${inType}"

mkdir -p "${out_dir}"
mkdir -p logs

############## input file list ##############

# One array task per FASTQ. Sorting keeps the array-index-to-sample mapping
# stable across runs, so re-running a single failed task hits the same sample.
mapfile -t files < <(find "${raw_dir}" -maxdepth 1 -type f -name "GMP5RJ*.fastq.gz" | sort)

# Fail loudly instead of silently doing nothing if the glob matched nothing.
if [[ ${#files[@]} -eq 0 ]]; then
    echo "ERROR: No FASTQ files found in ${raw_dir}"
    exit 1
fi

if [[ ${SLURM_ARRAY_TASK_ID} -ge ${#files[@]} ]]; then
    echo "ERROR: SLURM_ARRAY_TASK_ID ${SLURM_ARRAY_TASK_ID} exceeds FASTQ count ${#files[@]}"
    exit 1
fi

inFile1="${files[$SLURM_ARRAY_TASK_ID]}"

# Filenames are self-describing (3SQMBY_<n>_<condition>_<time>_rep_<r>), so the
# sample ID is just the basename without the extension. magdalena's
# `sed 's/_S.*//'` stripped an Illumina _S<n> suffix that these files do not carry.
uniqueID=$(basename "${inFile1}" .fastq.gz)

echo "Processing: ${uniqueID}"
echo "Input: ${inFile1}"

sample_out_dir="${out_dir}/${uniqueID}"
mkdir -p "${sample_out_dir}"

############## trimming ##############

# IMPORTANT - what these FASTQs already contain, checked directly on the data:
#
#  * The 14 bp UMI has ALREADY been moved into the read name by Plasmidsaurus,
#    e.g. @LH01042:...:1045_GTTACGTTGAACCA. It is NOT in the sequence, so there
#    is nothing here for Trim Galore to accidentally trim off as transcript.
#    Trim Galore does not modify read names, so the UMI survives this step and
#    is still there for umi_tools in 4.umi_dedup.sbatch.
#
#  * Adapters are already gone: the TruSeq adapter appears in 4 reads per
#    100,000 (0.00%), Nextera in none. Read lengths are already 50-94 rather
#    than a flat 94, i.e. the library has been trimmed upstream.
#
# --nextseq 20 replaces magdalena's --quality 20. These libraries were run on a
# NovaSeq X (instrument LH01042), a two-colour instrument where "no signal" is
# read as G. 1.98% of reads carry a 10+ bp poly-G run and 1.64% end in one.
# Plain quality trimming will NOT remove those, because the bases carry high
# quality scores; --nextseq treats high-quality G's at the 3' end as no-signal
# and trims them. This is the main thing left for Trim Galore to do here.
# Note --nextseq and --quality are mutually exclusive, so --quality is dropped.
#
# --length 16 is carried over from magdalena. It never binds on this data
# (shortest read is already 50 bp) but is left as-is rather than silently changed.
trim_galore \
    "${inFile1}" \
    --gzip \
    --fastqc \
    --nextseq 20 \
    --length 16 \
    -o "${sample_out_dir}"

echo "Finished ${uniqueID}"
