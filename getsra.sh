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

if [ -f "$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem"]; then
    SSH_FILE="$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem"
elif [ -f "$HOME/.aspera/etc/asperaweb_id_dsa.openssh"]; then
    SSH_FILE="$HOME/.aspera/etc/asperaweb_id_dsa.openssh"
else
    SSH_FILE=""
    echo "Could not find ascp private key file in system"
    exit 0
fi

for i in $(cat $INPUT);
do
    if [ ${#i} -gt 10 ]; then
        j="0${i:0-2:2}/"
    elif [ ${#i} -eq 10 ]; then
        j="00${i:0-1:1}/"
    else
        j=""
    fi
    ascp -T -l 300m -P33001 -i $SSH_FILE era-fasp@fasp.sra.ebi.ac.uk:vol1/fastq/${i:0:6}/${j}${i}/${i}_1.fastq.gz $OUTPUT/${i}_1.fastq.gz
    ascp -T -l 300m -P33001 -i $SSH_FILE era-fasp@fasp.sra.ebi.ac.uk:vol1/fastq/${i:0:6}/${j}${i}/${i}_2.fastq.gz $OUTPUT/${i}_2.fastq.gz
    if [ -f $OUTPUT/${i}_1.fastq.gz && $OUTPUT/${i}_2.fastq.gz]; then
        check_md5 ${i}
    else "miss paired fastq file"
    continue
done

function check_md5 {
    read md5_1 md5_2 <<< $(curl -G -d 'accession=$1' -d 'result=read_run' -d 'fields=fastq_md5' "https://www.ebi.ac.uk/ena/portal/api/filereport" | cut -f1 | tail -1 | tr ';' ' ')
    md5file_1=$(md5sum $OUTPUT/${1}_1.fastq.gz | cut -f1 -d ' ')
    md5file_2=$(md5sum $OUTPUT/${1}_2.fastq.gz | cut -f1 -d ' ')
    for i in 1 2
    do if [ $md5_${i} == $md5file_${i} ]; then 
        echo '$1_${i}.fastq.gz md5 is correct' >> enasra.log
    else
        echo '$1_${i}.fastq.gz md5 is not correct' >> enasra.log
    fi
}