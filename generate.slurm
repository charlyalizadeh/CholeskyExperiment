#!/bin/bash
#SBATCH --job-name=CholeskyExperiment
#SBATCH --output=/home/dist/charly-kyan.alizadeh/output.txt
#SBATCH --error=/home/dist/charly-kyan.alizadeh/error.txt

#SBATCH --ntasks=8

scontrol show hostnames $SLURM_JOB_NODELIST > hosts.$SLRUM_JOB_ID
first_hostname=$(head -n 1 hosts.$SLRUM_JOB_ID)

if [[ "$first_hostname" == $(hostname) ]]
then
    export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/usr/lib/x86_64-linux-gnu/"
    mongod --dbpath /home/dist/charly-kyan.alizadeh/repos/CholeskyExperiment/data/db --logpath /home/dist/charly-kyan.alizadeh/mongo.log
    #lsof | grep mongod
fi
srun julia generate.jl $first_hostname
