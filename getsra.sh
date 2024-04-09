#!/usr/bin/env bash
# Usage:
# getsra.sh -i list.txt -d diretory
# list.txt is the names of SRA accession list in a text file
# direcotry is the folder name to save fastq files

while getopts i:d: ARGS
do
    case $ARGS in
        i)
            INPUT=$OPTARG;;
        d)
            OUTPUT=$OPTARG;;
        ?)
            echo "`basename $0` usage: [-i input file] | [-d output directory]"
            exit 2;;
    esac
done

mkdir -p $OUTPUT

if [ -f "$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem" ]; then
    SSH_FILE="$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem"
elif [ -f "$HOME/.aspera/etc/asperaweb_id_dsa.openssh" ]; then
    SSH_FILE="$HOME/.aspera/etc/asperaweb_id_dsa.openssh"
else
    SSH_FILE=""
    echo "Could not find ascp private key file in system"
    exit 0
fi

function check_md5 {
    read md5_1 md5_2 <<< $(curl -G -d 'accession=$1' -d 'result=read_run' -d 'fields=fastq_md5' "https://www.ebi.ac.uk/ena/portal/api/filereport" | cut -f1 | tail -1 | tr ';' ' ')
    md5file_1=$(md5sum ${OUTPUT}/${1}_1.fastq.gz | cut -f1 -d ' ')
    md5file_2=$(md5sum ${OUOPUT}/${1}_2.fastq.gz | cut -f1 -d ' ')
    for i in 1 2
    do if [[ $md5_${i} == $md5file_${i} ]]; then 
        echo "$1_${i}.fastq.gz md5 is correct" >> ${OUTPUT}/enasra.log
    else
        echo "$1_${i}.fastq.gz md5 is not correct" >> ${OUTPUT}/enasra.log
    fi
    done
}

function get_fastq {
    if [ ${#1} -gt 10 ]; then
        nf="0${i:0-2:2}/"
    elif [ ${#1} -eq 10 ]; then
        nf="00${1:0-1:1}/"
    else
        nf=""
    fi
    for pe in 1 2
    do if [ ! -f "${OUTPUT}/${1}_${pe}.fastq.gz" ]; then
	ascp -T -l 300m -P33001 -i ${SSH_FILE} era-fasp@fasp.sra.ebi.ac.uk:vol1/fastq/${1:0:6}/${nf}${1}/${1}_${pe}.fastq.gz ${OUTPUT}/${1}_${pe}.fastq.gz
    fi
    done
}

for i in $(cat $INPUT);
do
    get_fastq ${i}
    check_md5 ${i}
done
