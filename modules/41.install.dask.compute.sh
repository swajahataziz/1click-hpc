#!/bin/bash
set -x
set -e

# Install Dask into Conda environment

. /shared/spack/share/spack/setup-env.sh
spack load miniconda3
conda init bash
conda create -n dask-env -c conda-forge -c anaconda dask dask-jobqueue dask-ml scikit-learn jupyter matplotlib pip python=3 requests xarray torchvision

# Activate the conda environment

. /shared/spack/share/spack/setup-env.sh
spack load miniconda3
conda activate dask-env

mkdir -p ~/.dask
cat << EOF > ~/.dask/jobqueue.yaml
# jobqueue.yaml file
jobqueue:
  slurm:
    cores: 4       # Cores per job (keep small to pack nodes)
    processes: 4   # Workers per job (share job cpu, mem)
    shebang: "#!/usr/bin/env bash"

    # Disable memory tracking (PCluster does not accept --mem resource by default)
    header_skip: 
      - '--mem'  
    # If header_skip disabled, memory per job (shared by processes)
    memory: 15GB

    # Local scratch for workers
    local-directory: /shared/dask

    # Number of seconds to wait if a worker can not find a scheduler
    death-timeout: 300   

    resource-spec: ""
    queue: batch
    project: my-project
    walltime: 01:00:00
    #job_extra:
    #  - '-C od-large'  # uncomment to constrain jobs to compute_resources (as named in PCluster Config)

    # In case jobs call mpi4py, we can influence config via environment
    env_extra: 
      - 'SLURM_MPI_TYPE=pmix'
      - 'OMPI_MCA_btl_tcp_if_exclude="lo,docker0,virbr0"'

    # This block replaces workers before the 1hr end of life 
    # and staggers replacement by 4min to ensure adequate time
    # to load balance
    extra:
      - "--lifetime"
      - "55m"
      - "--lifetime-stagger"
      - "4m"
EOF


sudo yum install -y chromium
cd ~
git clone https://github.com/dask/dask-examples.git
