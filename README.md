# enasra

Enasra is a tool to download WGS PE raw data from ENA. 

## Usage

**Installation**

```shell
# install requirements
$ mamba install aspera-cli curl aria2c

# download enasra
$ git clone https://github.com/indexofire/enasra.git
```

**Download data**

1. Prepare a SRA/ERA/DRA accession list text file. Use entrez-direct or NCBI/ENA web page tools to extract what you need.

2. run `get_enafq` pipeline.

```shell
# create list or you can download a list from NCBI
$ echo -e "DRR178303\nERR044749\nERR2668680" > list

# run pipeline to download
$ ./get_enafq.sh -i list

# run pipeline to download in 2 connections
$ ./get_enafq.sh -i list -j2

# use wget to download via ftp method
$ ./get_enafq.sh -m ftp -t wget -i list -d output
```

**Checksum**

```shell
# md5sum had checked when downloading, you can manually check again
$ cd output
$ for i in *.txt; do md5sum -c $i; done | grep -v OK
```

**Recommendation**

This is a tiny pipeline used for myself daily. If you need a full software to download raw data of WGS in public database, I recommend something real, like [kingfisher](https://github.com/wwood/kingfisher-download), [sra-tools](https://github.com/ncbi/sra-tools), etc.
