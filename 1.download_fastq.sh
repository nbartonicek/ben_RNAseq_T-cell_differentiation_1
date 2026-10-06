#!/bin/bash
#SBATCH --job-name=plasmidsaurus_fastq
#SBATCH --time=4-00:00:00
#SBATCH --partition=rhel_long
#SBATCH --cpus-per-task=1
#SBATCH --mem=2G
#SBATCH --output=plasmidsaurus_%j.out
#SBATCH --error=plasmidsaurus_%j.err

# Where you want the FASTQ zip
cd /scratch/users/nbartonicek/projects/ben_legg/scripts

# Plasmidsaurus signed download URL
URL='https://plasmidsaurus-prod.s3.amazonaws.com/customer_fastq/3SQMBY_fastq.zip...'

echo "Starting Plasmidsaurus download"
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "Destination: $(pwd)/3SQMBY_fastq.zip"

# Remove any tiny/error file from previous failed attempts.
# COMMENT THIS LINE OUT if you already have a genuine large download
# that you want to preserve.
rm -f 3SQMBY_fastq.zip

wget \
    --timeout=60 \
    --read-timeout=60 \
    --tries=20 \
    --waitretry=30 \
    -O 3SQMBY_fastq.zip \
    "$URL"

echo
echo "Download finished: $(date)"
ls -lh 3SQMBY_fastq.zip
