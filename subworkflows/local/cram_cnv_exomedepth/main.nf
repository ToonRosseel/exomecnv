/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { EXOMEDEPTH_COUNT                  } from '../../../modules/local/exomedepth/count/main'
include { CUSTOM_MERGECOUNTS                } from '../../../modules/local/custom/mergecounts/main'
include { EXOMEDEPTH_CALL                   } from '../../../modules/local/exomedepth/call/main'
include { CUSTOM_MERGECNV                   } from '../../../modules/local/custom/mergecnv/main'
include { BEDGOVCF                          } from '../../../modules/nf-core/bedgovcf/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN EXOMEDEPTH WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CRAM_CNV_EXOMEDEPTH {

    take:
    ch_bams    // meta, bam, bai
    ch_bed     // meta, bed
    chromosome // string

    main:
    def ch_versions = Channel.empty()

    //MODULE: Count autosomal reads per sample (count file for each sample)

    def ch_count_input = ch_bams
        .map { meta, bam, bai ->
            def new_meta = meta + [chromosome:chromosome]
            [ new_meta, bam, bai, meta.id ]
        }

    EXOMEDEPTH_COUNT (
        ch_count_input,
        ch_bed
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_COUNT.out.versions.first())

    //MODULE: Group autosomal counts per batch (count file for each batch)

    def ch_grouped_counts = EXOMEDEPTH_COUNT.out.counts
        .map { meta, txt ->
            def new_meta = meta + [id:meta.batch] - meta.subMap("family")
            [groupKey(new_meta, new_meta.samples.tokenize(",").size), txt]
        }
        .groupTuple()

    CUSTOM_MERGECOUNTS(
        ch_grouped_counts
    )
    ch_versions = ch_versions.mix(CUSTOM_MERGECOUNTS.out.versions.first())

    //MODULE: Autosomal CNV call per sample (file for each sample)

    def ch_counts = CUSTOM_MERGECOUNTS.out.merge
        .map { meta, txt ->
            [meta, txt, meta.samples.tokenize(","), meta.samples, meta.families]
        }
        .transpose(by:2)
        .map { meta, txt, sample, samples, families ->
            def new_meta = meta + [id:sample]
            [ new_meta, txt, sample, samples, families ]
        }

    EXOMEDEPTH_CALL(
        ch_counts,
        ch_bed
    )
    ch_versions = ch_versions.mix(EXOMEDEPTH_CALL.out.versions.first())

    def ch_cnv_out = EXOMEDEPTH_CALL.out.cnvcall
        .map { meta, txt ->
            def new_meta = meta - meta.subMap("chromosome")
            [ new_meta, txt ]
        }

    emit:
    versions = ch_versions
    cnv = ch_cnv_out
}
