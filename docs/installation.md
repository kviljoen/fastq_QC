# fastq_QC Installation

To start using the fastq_QC, follow the steps below:

1. [Install Nextflow](#install-nextflow)
2. [Install the pipeline](#install-the-pipeline)

## 1) Install NextFlow
Nextflow runs on most POSIX systems (Linux, Mac OSX etc). It can be installed by running the following commands:

```bash
# Make sure that Java v7+ is installed:
java -version

# Install Nextflow
curl -fsSL get.nextflow.io | bash

# Add Nextflow binary to your PATH:
mv nextflow ~/bin
# OR system-wide installation:
sudo mv nextflow /usr/local/bin
```

### For Univeristy of Cape Town users working on HPC:
```
#From your home directory on hex install nextflow
curl -fsSL get.nextflow.io | bash

#Add the following to ~/.bashrc:
JAVA_HOME=/opt/exp_soft/java/jdk1.8.0_31/
JAVA_CMD=/opt/exp_soft/java/jdk1.8.0_31/bin/java

#Do not run nextflow from the headnode, it requires substantial memory to run java. Please therefore first start an interactive job as follows: 
qsub -I -q UCTlong -l nodes=1:series600:ppn=1 -d `pwd`
```

**You need NextFlow version >= 0.24 to run this pipeline.**

See [nextflow.io](https://www.nextflow.io/) and [NGI-NextflowDocs](https://github.com/SciLifeLab/NGI-NextflowDocs) for further instructions on how to install and configure Nextflow.

## 2) Install the Pipeline
This pipeline itself needs no installation - NextFlow will automatically fetch it from GitHub if `kviljoen/fastq_QC` is specified as the pipeline name when executing `nextflow run kviljoen/fastq_QC`. If for some reason you need to use the development branch, this can be specified as `nextflow run kviljoen/fastq_QC -r dev`

### Offline use

If you need to run the pipeline on a system with no internet connection, you will need to download the files yourself from GitHub and run them directly:

```bash
wget https://github.com/kviljoen/fastq_QC/archive/master.zip
unzip master.zip -d /my-pipelines/
cd /my_data/
nextflow run /my-pipelines/fastq_QC
```
## 3) Other requirements

fastQC requires a list of adapter sequences:

- a FASTA file listing the adapter sequences to remove in the trimming step. This file should be available within the BBmap installation. If not, please download it from [here](https://github.com/BioInfoTools/BBMap/blob/master/resources/adapters.fa);
- two FASTA files describing synthetic contaminants. These files (`sequencing_artifacts.fa.gz` and `phix174_ill.ref.fa.gz`) should be available within the BBmap installation. If not, please download them from [here](https://sourceforge.net/projects/bbmap/);

## 4) Docker and/or Singularity setup
If you are not working on UCT HPC, you may have to adapt the dockerfile in this repository for your own use, e.g. to add user-defined bind points. The `Dockerfile` can be built into a docker image on your own system (where docker has been installed) as follows:

First pull the git repository e.g. :
```
git clone https://github.com/kviljoen/fastq_QC.git
```

Now build a local image by navigating to the folder where the `Dockerfile` is located and running the following command (be careful to add the dot!):

```
docker build -t fast_QC_docker .
```
If you are working on a cluster environment you will likely have to convert the docker image to a singularity image. This can be done using [docker2singularity](https://github.com/singularityware/docker2singularity), e.g. as follows:

```
docker run -v /var/run/docker.sock:/var/run/docker.sock -v /home/katie/h3abionet16S/singularity-containers/:/output --privileged -t --rm singularityware/docker2singularity d02667d8d22e
```
Where `/home/katie/h3abionet16S/singularity-containers/` is the location where you want to save your singularity image and `d02667d8d22e` is the docker image ID obtained via `docker images` command

Next, test the singularity image:

```
singularity exec /scratch/DB/bio/singularity-containers/d02667d8d22e-2018-07-23-251e39cb1b13.img /bin/bash
```

Where `d02667d8d22e-2018-07-23-251e39cb1b13.img` is your singularity image. You are now in the singularity image environment and can test whether all software was successfully installed e.g. fastqc --help should print the relevant helpfile.



---

[![UCT Computational Biology](/assets/cbio_logo.png)](http://www.cbio.uct.ac.za/)

---
