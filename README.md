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
$ echo -e "DRR123021\nERR1351990" > list

# run pipeline to download
$ ./getend.sh -i list -d output
# or you want to run it backend
$ nohup ./getend.sh -i list -d output &

# check md5sum result
$ cat output/enasra.log
