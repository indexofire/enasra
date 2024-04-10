# enasra

Enasra is a tool to download WGS PE raw data from ENA.

## Usage

**Installation**

```shell
# install requirements
$ mamba install aspera-cli curl

# download enasra
$ git clone https://github.com/indexofire/enasra.git
```

**Download data**

```shell
# create list or you can download a list from NCBI
$ echo -e "DRR178303\nERR044749\nERR2668680" > list

# run pipeline to download
$ ./getsra.sh -i list -d output

# or you want to run it backend
$ nohup ./getsra.sh -i list -d output &
```

**Checksum**

```shell
# md5sum check
$ cd output
$ md5sum -c md5sum.txt
```
