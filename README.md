# ![kviljoen/YAMP](/assets/cbio_logo.png)

# fastq_QC: fastQC, Illumina adapter removal, filtering, trimming, multiQC reports

This nextflow pipeline accepts raw reads in .fastq format, performs quality filtering, adapter removal.

## Basic usage:

    The typical command for running the pipeline is as follows:
    nextflow run uct-cbio/uct-yamp --reads '*_R{1,2}.fastq.gz' -profile uct_hex

    Mandatory arguments:
      --reads			Path to input data (must be surrounded with quotes)
      -profile			Hardware config to use. uct_hex OR standard
      
    BBduk trimming options:
      --qin			Input quality offset: 33 (ASCII+33) or 64 (ASCII+64, default=33
      --kcontaminants		Kmer length used for finding contaminants, default=23	
      --phred			Regions with average quality BELOW this will be trimmed, default=10 
      --minlength		Reads shorter than this after trimming will be discarded, default=60
      --mink			Shorter kmers at read tips to look for, default=11 
      --hdist			Maximum Hamming distance for ref kmers, default=1            
    
    Other options:
      --keepQCtmpfile		Whether the temporary files resulting from QC steps should be kept, default=false
      --outdir			The output directory where the results will be saved
      --email                   Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                     Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
      
     Help:
      --help			Will print out summary above when executing nextflow run uct-cbio/uct-yamp --help 


## Prerequisites

Nextflow (0.26.x or higher), all other software/tools required are contained in the (platform-independent) dockerfile, which should be converted to a singularity image for use on a cluster environment. If you are working on the UCT cluster, all necessary singularity images are specified in the uct_hpc.conf profile. If you are working on another cluster environment you would need to build your own singularity image, using the Dockerfile in this repo as a starting point, specifying your own relevant working directories using ```RUN mkdir -p```

## Documentation
The uct-yamp pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. [Running the pipeline](docs/usage.md)
3. [Pipeline results breakdown](docs/results_breakdown.md)

## Built With

* [Nextflow](https://www.nextflow.io/)
* [Docker](https://www.docker.com/what-docker)
* [Singularity](https://singularity.lbl.gov/)


## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details


