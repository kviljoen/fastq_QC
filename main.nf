#!/usr/bin/env nextflow
/*
========================================================================================
                              QC   P I P E L I N E
========================================================================================
 
 
----------------------------------------------------------------------------------------
*/

/**
	Prints help when asked for
*/

def helpMessage() {
    log.info"""
    ===================================
     fastq_QC  ~  version ${params.version}
    ===================================
    Usage:
    The typical command for running the pipeline is as follows:
    nextflow run kviljoen/fastq_QC --reads '*_R{1,2}.fastq.gz' -profile uct_hpc
    Mandatory arguments:
      --reads                       Path to input data (must be surrounded with quotes)
      -profile                      Hardware config to use. uct_hex OR standard
      
    BBduk trimming options:
      --qin			    Input quality offset: 33 (ASCII+33) or 64 (ASCII+64, default=33
      --kcontaminants		    Kmer length used for finding contaminants, default=23	
      --phred			    Regions with average quality BELOW this will be trimmed, default=10 
      --minlength		    Reads shorter than this after trimming will be discarded, default=60
      --mink			    Shorter kmers at read tips to look for, default=11 
      --hdist			    Maximum Hamming distance for ref kmers, default=1            

      
    Other options:
      --outdir                      The output directory where the results will be saved
      --email                       Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits
      -name                         Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.
      
     Help:
      --help                        Will print out summary above when executing nextflow run uct-cbio/uct-yamp --help                                    
    """.stripIndent()
}
	
/*
 * SET UP CONFIGURATION VARIABLES
 */

// Configurable variables
params.name = false
//params.project = false
params.email = false
params.plaintext_email = false


// Show help emssage
params.help = false
if (params.help){
    helpMessage()
    exit 0
}
 

if (params.qin != 33 && params.qin != 64) {  
	exit 1, "Input quality offset (qin) not available. Choose either 33 (ASCII+33) or 64 (ASCII+64)" 
}   

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if( !(workflow.runName ==~ /[a-z]+_[a-z]+/) ){
  custom_runName = workflow.runName
}

// Returns a tuple of read pairs in the form
// [sample_id, forward.fq, reverse.fq] where
// the dataset_id is the shared prefix from
// the two paired FASTQ files.
Channel
    .fromFilePairs( params.reads )
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .into { ReadPairsToQual; ReadPairs }

//Input reference files validation:
//BDUK reference files:
Channel
    .fromPath(params.adapters)
    .ifEmpty { exit 1, "BBDUK adapter file not found: ${params.adapters}"  }
    .into { adapters_ref }
Channel
    .fromPath(params.artifacts)
    .ifEmpty { exit 1, "BBDUK adapter file not found: ${params.artifacts}"  }
    .into { artifacts_ref }
Channel
    .fromPath(params.phix174ill)
    .ifEmpty { exit 1, "BBDUK phix file not found: ${params.phix174ill}"  }
    .into { phix174ill_ref }
      

// Header log info
log.info "==================================="
log.info " fastq_QC  ~  version ${params.version}"
log.info "==================================="
def summary = [:]
summary['Run Name']     = custom_runName ?: workflow.runName
summary['Reads']        = params.reads
summary['OS']		= System.getProperty("os.name")
summary['OS.arch']	= System.getProperty("os.arch") 
summary['OS.version']	= System.getProperty("os.version")
summary['javaversion'] = System.getProperty("java.version") //Java Runtime Environment version
summary['javaVMname'] = System.getProperty("java.vm.name") //Java Virtual Machine implementation name
summary['javaVMVersion'] = System.getProperty("java.vm.version") //Java Virtual Machine implementation version
//Gets starting time		
sysdate = new java.util.Date() 
summary['User']		= System.getProperty("user.name") //User's account name
summary['Max Memory']     = params.max_memory
summary['Max CPUs']       = params.max_cpus
summary['Max Time']       = params.max_time
summary['Output dir']     = params.outdir
summary['Working dir']    = workflow.workDir
summary['Container']      = workflow.container
if(workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Current home']   = "$HOME"
summary['Current user']   = "$USER"
summary['Current path']   = "$PWD"
summary['Script dir']     = workflow.projectDir
summary['Config Profile'] = workflow.profile
if(params.email) {
    summary['E-mail Address'] = params.email
}
log.info summary.collect { k,v -> "${k.padRight(15)}: $v" }.join("\n")
log.info "========================================="

		
/*
 *
 * Step 1: FastQC (run per sample)
 *
 */

process runFastQC {
    cache 'deep'
    tag { "rFQC.${pairId}" }

    publishDir "${params.outdir}/FilterAndTrim", mode: "copy"

    input:
        set pairId, file(in_fastq) from ReadPairsToQual

    output:
        file("${pairId}_fastqc/*.zip") into fastqc_files

    """
    mkdir ${pairId}_fastqc
    fastqc --outdir ${pairId}_fastqc \
    ${in_fastq.get(0)} \
    ${in_fastq.get(1)}
    """
}

process runMultiQC{
    cache 'deep'
    tag { "rMQC" }

    publishDir "${params.outdir}/FilterAndTrim", mode: 'copy'

    input:
        file('*') from fastqc_files.collect()

    output:
        file('multiqc_report.html')

    """
    multiqc .
    """
}


/*
 *
 * Step 2: BBDUK: trim + filter (run per sample)
 *
 */

process bbduk {
	cache 'deep'
	tag{ "bbduk.${pairId}" }
	
	publishDir "${params.outdir}/bbduk", mode: "copy"
	
	input:
	set val(pairId), file(reads) from ReadPairs
	file adapters from adapters_ref.collect()
	file artifacts from artifacts_ref.collect()
	file phix174ill from phix174ill_ref.collect()

	output:
	set val(pairId), file("${pairId}_trimmed_R1.fq"), file("${pairId}_trimmed_R2.fq") into filteredReadsforQC

	script:
	markdup_java_options = (task.memory.toGiga() < 8) ? ${params.markdup_java_options} : "\"-Xms" +  (task.memory.toGiga()/10 )+"g "+ "-Xmx" + (task.memory.toGiga()-8)+ "g\""

	"""	
	#Quality and adapter trim:
	bbduk.sh ${markdup_java_options} in="${reads[0]}" in2="${reads[1]}" out=${pairId}_trimmed_R1_tmp.fq \
	out2=${pairId}_trimmed_R2_tmp.fq outs=${pairId}_trimmed_singletons_tmp.fq ktrim=r \
	k=$params.kcontaminants tossjunk=t mink=$params.mink hdist=$params.hdist qtrim=rl trimq=$params.phred \
	minlength=$params.minlength ref=$adapters qin=$params.qin threads=${task.cpus} tbo tpe 
	
	#Synthetic contaminants trim:
	bbduk.sh ${markdup_java_options} in=${pairId}_trimmed_R1_tmp.fq in2=${pairId}_trimmed_R2_tmp.fq \
	out=${pairId}_trimmed_R1.fq tossjunk=t out2=${pairId}_trimmed_R2.fq k=31 ref=$phix174ill,$artifacts \
	qin=$params.qin threads=${task.cpus} 

	#Removes tmp files. This avoids adding them to the output channels
	rm -rf ${pairId}_trimmed*_tmp.fq 

	"""
}


/*
 *
 * Step 3: FastQC post-filter and -trim (run per sample)
 *
 */

process runFastQC_postfilterandtrim {
    cache 'deep'
    tag { "rFQC_post_FT.${pairId}" }

    publishDir "${params.outdir}/FastQC_post_filter_trim", mode: "copy"

    input:
    	set val(pairId), file("${pairId}_trimmed_R1.fq"), file("${pairId}_trimmed_R2.fq") from filteredReadsforQC

    output:
        file("${pairId}_fastqc_postfiltertrim/*.zip") into fastqc_files_2

    """
    mkdir ${pairId}_fastqc_postfiltertrim
    fastqc --outdir ${pairId}_fastqc_postfiltertrim \
    ${pairId}_trimmed_R1.fq \
    ${pairId}_trimmed_R2.fq
    """
}

process runMultiQC_postfilterandtrim {
	cache 'deep'
    tag { "rMQC_post_FT" }

    publishDir "${params.outdir}/FastQC_post_filter_trim", mode: 'copy'

    input:
        file('*') from fastqc_files_2.collect()

    output:
        file('multiqc_report.html')

    """
    multiqc .
    """
}

/*
 *
 * Step 4: Completion e-mail notification
 *
 */
workflow.onComplete {
  
    def subject = "[fastq_QC] Successful: $workflow.runName"
    if(!workflow.success){
      subject = "[fastq_QC] FAILED: $workflow.runName"
    }
    def email_fields = [:]
    email_fields['version'] = params.version
    email_fields['runName'] = custom_runName ?: workflow.runName
    email_fields['success'] = workflow.success
    email_fields['dateComplete'] = workflow.complete
    email_fields['duration'] = workflow.duration
    email_fields['exitStatus'] = workflow.exitStatus
    email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
    email_fields['errorReport'] = (workflow.errorReport ?: 'None')
    email_fields['commandLine'] = workflow.commandLine
    email_fields['projectDir'] = workflow.projectDir
    email_fields['summary'] = summary
    email_fields['summary']['Date Started'] = workflow.start
    email_fields['summary']['Date Completed'] = workflow.complete
    email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
    email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
    if(workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
    if(workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
    if(workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
    if(workflow.container) email_fields['summary']['Docker image'] = workflow.container

    // Render the TXT template
    def engine = new groovy.text.GStringTemplateEngine()
    def tf = new File("$baseDir/assets/email_template.txt")
    def txt_template = engine.createTemplate(tf).make(email_fields)
    def email_txt = txt_template.toString()

    // Render the HTML template
    def hf = new File("$baseDir/assets/email_template.html")
    def html_template = engine.createTemplate(hf).make(email_fields)
    def email_html = html_template.toString()

    // Render the sendmail template
    def smail_fields = [ email: params.email, subject: subject, email_txt: email_txt, email_html: email_html, baseDir: "$baseDir" ]
    def sf = new File("$baseDir/assets/sendmail_template.txt")
    def sendmail_template = engine.createTemplate(sf).make(smail_fields)
    def sendmail_html = sendmail_template.toString()

    // Send the HTML e-mail
    if (params.email) {
        try {
          if( params.plaintext_email ){ throw GroovyException('Send plaintext e-mail, not HTML') }
          // Try to send HTML e-mail using sendmail
          [ 'sendmail', '-t' ].execute() << sendmail_html
          log.info "[uct-yamp] Sent summary e-mail to $params.email (sendmail)"
        } catch (all) {
          // Catch failures and try with plaintext
          [ 'mail', '-s', subject, params.email ].execute() << email_txt
          log.info "[uct-yamp] Sent summary e-mail to $params.email (mail)"
        }
    }
}
