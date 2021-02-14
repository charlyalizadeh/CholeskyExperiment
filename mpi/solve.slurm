#!/bin/bash
#SBATCH --job-name=CholeskyExperiment
#SBATCH --output=/home/dist/charly-kyan.alizadeh/repos/CholeskyExperiment/data/magi/output.txt
#SBATCH --error=/home/dist/charly-kyan.alizadeh/repos/CholeskyExperiment/data/magi/error.txt

#SBATCH --ntasks=4

scontrol show hostnames $SLURM_JOB_NODELIST > hosts.$SLRUM_JOB_ID
first_hostname = $(head -n 1 hosts.$SLRUM_JOB_ID)

if $first_hostname == `hostname` then
    mongod --dbpath /home/dist/charly-kyan.alizadeh/repos/CholeskyExperiment/data/db
fi

srun julia solve.jl $first_hostname

rm -f hosts.$SLURM_JOB_ID
