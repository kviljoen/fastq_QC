FROM debian:jessie

#Exports conda path
ENV PATH $PATH:/opt/conda/bin/

RUN apt-get update && apt-get install -y --no-install-recommends \
    bzip2 \
    libglib2.0-0 \
    libxext6 \
    libsm6 \
    libxrender1 \
    wget \
    ca-certificates \
    bash \
    procps \
    wget \
    curl \
    gzip \
    perl && \
    wget --quiet https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh && \
    /bin/bash /Miniconda3-latest-Linux-x86_64.sh -b -p /opt/conda && \
    /opt/conda/bin/conda install --yes conda && \
    conda install conda-build && \
    #Update conda and uses it to install software used by YAMP
    #that is required to use YAMP on AWS Batch && \
    conda install -c bioconda -y bbmap fastqc multiqc metaphlan2 qiime humann2 &&\
    conda install -c conda-forge -y awscli &&\
    conda clean --yes --tarballs --packages --source-cache
