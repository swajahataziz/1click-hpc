#!/bin/bash
set -x
set -e

# Install Spack
cd /shared/
git clone https://github.com/spack/spack 
. /shared/spack/share/spack/setup-env.sh

which spack
mkdir -p ~/.spack
# Configure Spack packages

sudo bash /fsx/1click-hpc/scripts/setup_dask_env.sh

cat << EOF > ~/.spack/packages.yaml
packages:
  all:
    providers:
      mpi:
        - openmpi
        - intel-mpi
        - mpich
    variants: +mpi
  openmpi: 
    buildable: true
    variants: fabrics=ofi +pmi +legacylaunchers schedulers=slurm
    version: [4.1.0]
    externals:
      - spec: openmpi@4.1.0 fabrics=ofi +pmi +legacylaunchers schedulers=slurm
        modules:
        - openmpi/4.1.0
  intel-mpi:
    buildable: true
    version: [2020.2.254]
    externals:
      - spec: intel-mpi@2020.2.254
        modules:
        - intelmpi
  mpich:
    variants: ~wrapperrpath pmi=pmi netmod=ofi device=ch4
  libfabric:
    buildable: true
    variants: fabrics=efa,tcp,udp,sockets,verbs,shm,mrail,rxd,rxm
    version: [1.11.1]
    externals:
      - spec: libfabric@1.11.1 fabrics=efa,tcp,udp,sockets,verbs,shm,mrail,rxd,rxm
        modules:
        - libfabric-aws/1.11.1amzn1.0
  slurm:
    buildable: true
    variants: +pmix sysconfdir=/opt/slurm/etc
    version: [20-02-4-1]
    externals:
    - spec: slurm@20-02-4-1 +pmix sysconfdir=/opt/slurm/etc
      prefix: /opt/slurm/
  munge:
    # Refer to ParallelCluster global munge space
    variants: localstatedir=/var
EOF
spack config blame packages
# Configure Spack Modules

cat << EOF > ~/.spack/modules.yaml
modules:
  enable:
    - tcl
  tcl:
    verbose: True
    hash_length: 6
    projections:
      all: '{name}/{version}-{compiler.name}-{compiler.version}'
      ^libfabric: '{name}/{version}-{^mpi.name}-{^mpi.version}-{^libfabric.name}-{^libfabric.version}-{compiler.name}-{compiler.version}'
      ^mpi: '{name}/{version}-{^mpi.name}-{^mpi.version}-{compiler.name}-{compiler.version}'
    blacklist:
      - slurm
    all:
      conflict:
        - '{name}'
      environment:
        set:
          '{name}_ROOT': '{prefix}'
      autoload:  direct
    openmpi:
      environment:
        set:
          SLURM_MPI_TYPE: "pmix"
          OMPI_MCA_btl_tcp_if_exclude: "lo,docker0,virbr0"
    miniconda3:
      environment:
        set:
          CONDA_PKGS_DIRS: ~/.conda/pkgs
          CONDA_ENVS_PATH: ~/.conda/envs
EOF

# Install Miniconda
. /shared/spack/share/spack/setup-env.sh
spack install miniconda3
