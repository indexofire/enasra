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
# md5sum check
$ cd output
$ for i in *.txt; do md5sum -c $i; done | grep -v OK
```
