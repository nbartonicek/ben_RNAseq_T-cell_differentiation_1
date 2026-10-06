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
URL='https://plasmidsaurus-prod.s3.amazonaws.com/customer_fastq/3SQMBY_fastq.zip?AWSAccessKeyId=ASIAQ3VFTI337LBA76KC&Signature=uI%2FktwywEIik1cq6GbJ42euJgSw%3D&x-amz-security-token=IQoJb3JpZ2luX2VjEML%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FwEaCXVzLXdlc3QtMiJHMEUCIQCrr5mOIK8ZcumFQWZe8OAWKu37G5jzPRe39WKbgtNa8gIgBjwkyDx0jFnwkHd2kAhlB3%2BOz8FezX5uBw3%2B8ytXKZUqmAQIi%2F%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARACGgwwNTk0MDMwOTM3NTEiDLgCHdHM%2BY4kEx76RirsA0AZQ0H1EJ4pJBfmleQzmtGQnnRkWKIXcfgwkMWb2zEg0A2YfTKQONZc1qB8YJXvIOj32Vk402rckFSR2L5Vb5LOl35XQUlO3bKFiO3tWXCAfeeB%2BERAvdOVvXSWZjYXVwHXqvwUQ2eNP8WJKRjoyetscPFPvTUPRWbrAWIMS7HjGpvY68mZGUPTyW0W%2Bo5%2BQQjXXeB5BMFksCj%2FOS4AMQwzL1BOAySxBuZBCVFyeKsUZ8Zljrp89gfkmI0bKhWmIBbvMw2fWvvldxOXFVPYyaAIxgCeArCWAQayVxV676HFfUfmgn8jHDPGI4t85Nc7GTJCeMyg%2F7ztRWe8GG6YY3ey5jHfSB%2BgPV7JcK8vKaoPkq4%2FOyPb8fNju0dZesN2UOiF5roP5pjiy%2B8cx%2FTsLjZJWM3ClhaIlbxEo9JgA64IKe1nLK8nGgRWIqHzNFY8tkd4MiYZl%2B1tlpgPDus4jVdzoad9l7%2BtnG8PmPZz%2F7vQz4t1GytTCIzRTbLsGoWC6QouUeuGb1b8XTNir7i451nY7ejyCUegFVhCalrUBHoHVy8XBQMOJ7HHuLrOqr1IJB9ZHTdzPZFQcNp9dPNAgIwRtCnsA0N5sko3GbQnf8Z1DcMsAILqNrsrY2z0mRG%2FWGmcMnnJf2huMwfn2jCiw9PUBjqmAYwAEDgEy7%2FkNaAIN74a%2BIu1d6veCCeb1%2BUk2969pmBFWoDo6xN8UtrMd74gZHSPEGCl4avGzCRCFm%2F%2FhrHMTP4SCRFm%2Fu6lHvvF3bbulg00nNyUcPgUbXUiW0e81jOzClteNL4PPvZ1PtN30Zl%2BB3Tuh3VRAeqKhQBWErfsju74%2FYo6fP%2FsVw9vcWfG7zbkBzDXVo7L1vGUaHLlYqmicnu7QAO6TeU%3D&Expires=1788161303'

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