#!/usr/bin/env bash
# Usage:
# getsra.sh -m ascp -i list.txt -d diretory
# list.txt is the names of SRA accession list in a text file
# direcotry is the folder name to save fastq files

while getopts m:i:d: ARGS
do
    case $ARGS in
	m)
	    METHOD=$OPTARG;;
        i)
            INPUT=$OPTARG;;
        d)
            OUTPUT=$OPTARG;;
        ?)
            echo "`basename $0` usage: [-m download method] [-i input file] | [-d output directory]"
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

function get_md5 {
    read md5_1 md5_2 <<< $(curl -G -s -d "accession=$1" -d "result=read_run" -d "fields=fastq_md5" "https://www.ebi.ac.uk/ena/portal/api/filereport" | cut -f1 | tail -1 | tr ';' ' ')
    echo "${md5_1} ${1}_1.fastq.gz" >> ${OUTPUT}/md5sum.txt
    echo "${md5_2} ${1}_2.fastq.gz" >> ${OUTPUT}/md5sum.txt
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
	if [[ ${METHOD} == "ftp" ]]; then
	    aria2c ftp://ftp.sra.ebi.ac.uk/vol1/fastq/${1:0:6}/${nf}${1}/${1}_${pe}.fastq.gz -d ${OUTPUT}
	else
	    ascp -T -l 300m -P33001 -i ${SSH_FILE} era-fasp@fasp.sra.ebi.ac.uk:vol1/fastq/${1:0:6}/${nf}${1}/${1}_${pe}.fastq.gz ${OUTPUT}/${1}_${pe}.fastq.gz
	fi
    fi
    done
}

for i in $(cat $INPUT);
do
    get_fastq ${i}
    if [[ $(grep -n ${i} ${OUTPUT}/md5sum.txt | wc -l) < 2 ]]; then
	get_md5 ${i}
    fi
done
