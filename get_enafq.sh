#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Tool readme:
# 国内个人使用 NCBI prefetch 下载 sra 很慢，目前又暂时不支持 ascp。而对gcp/aws等
# 使用又有一定的门槛。
# 比较 ENA, DDBJ, NGDC 后，本地下载原始数据最快的还是ENA的 ascp 模式，因此开发了
# 这个下载工具。目前只支持PE格式的测序数据。
# Author: indexofire<indexofire@gmail.com>
# -----------------------------------------------------------------------------
set -euo pipefail

# VERSION
VERSION="0.0.1"

# 显示版本号
show_version() {
    echo "get_enafq version: $VERSION"
    exit 0
}

# 显示帮助信息
show_help() {
    echo "get_enafq - 从ENA批量下载FASTQ文件的工具"
    echo "            将SRA登录号保存形成列表文件，即可下载"
    echo "使用方法:"
    echo "  $0 [选项]"
    usage
    echo "选项:"
    echo "  -h, --help     显示帮助信息"
    echo "  -v, --version  显示版本号"
    exit 0
}

usage() {
    echo "示例:"
    echo "  $0 -m [ascp|ftp] -i input.txt -d output_dir [-t ftp_tool] [-j jobs]"
    echo "参数:"
    echo "  -m: Download method (ascp/ftp, default: ascp)"
    echo "  -i: Input file listed in SRA accession numbers"
    echo "  -d: Output directory for FASTQ files (default: output)"
    echo "  -t: FTP download tool if -m ftp used (aria2c/curl/wget, default: aria2c)"
    echo "  -j: Number of parallel download jobs (max is 3)"
    exit 1
}

# 依赖软件检查
check_dependencies() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "Error: $cmd not found. Please install it first."
        exit 1
    fi
}

# 检查asper密钥
find_aspera_key() {
    local ssh_file
    # v4 aspera-cli 使用 aspera_bypass_dsa.pem
    # 如果还使用的是v3版本，会找不到密钥文件，请更新aspera
    ssh_file="$CONDA_PREFIX/etc/aspera/aspera_bypass_dsa.pem" 2>/dev/null

    [[ -f "$ssh_file" ]] || {
        echo "Error: Aspera private key not found."
        echo "You may not in the correct conda environment"
        echo "Otherwise, maybe not installed or installed wrong version of aspera-cli."
        exit 1
    }
    echo "$ssh_file"
}

# 格式化ENA的下载路径
generate_path() {
    local acc="$1"
    # 生成路径
    awk -v acc="${acc}" -v len="${#acc}" 'BEGIN{
        if (len==11) {
            dir = "0" substr(acc, len-1, 2)
        } else if (len==10) {
            dir = "00" substr(acc, len, 1)
        } else {
            dir = ""
        }
        printf "%s/%s/%s", substr(acc, 1, 6), dir, acc
    }'
}

# 通过ENA api获得fastq的MD5信息
fetch_md5() {
    local acc="$1"
    local url="https://www.ebi.ac.uk/ena/portal/api/filereport"
    local response

    # 如果md5文件已存在，则跳过
    [[ ! -f "${OUTPUT}/${acc}_md5sum.txt" ]] || return 1

    # API数据抓取
    response=$(curl -fsSL -G \
        -d "accession=$acc" \
        -d "result=read_run" \
        -d "fields=fastq_md5,fastq_ftp" \
        "$url")
    
    [[ -z "$response" ]] && return 1

    # 解析实际存在的文件
    local fqs=()
    IFS=';' read -ra fq_files <<< $(echo "$response" | awk -F'\t' 'NR>1 {print $2}')
    for fq in "${fq_files[@]}"; do
        fqs+=("$(basename "$fq")")
    done

    # 生成MD5校验文件
    echo "$response" | awk -F'\t' -v fqs_str="$(printf '%s\n' "${fqs[@]}")" '
    BEGIN{
        split(fqs_str, fs, "\n")
    }
    NR>1 {
        split($3, md5, ";");
        for (i=1; i<=length(md5); i++) {
            print md5[i] " " fs[i] 
        }
    }' > "${OUTPUT}"/"${acc}_md5sum.txt"
}

# 校验函数
verify_md5() {
    local acc="$1"
    local md5_file="${OUTPUT}/${acc}_md5sum.txt"

    [[ -f "$md5_file" ]] || return 1

    # 只校验实际存在的文件
    local files_exist=()
    for fn in "${OUTPUT}/${acc}"_?.fastq.gz; do
        [[ -f $fn ]] && files_exist+=("$(basename "$fn")")
    done
    # 校验
    md5sum -c --quiet <(awk -v output="${OUTPUT}/" '{print $1,output$2}' $md5_file) 2>/dev/null
    # 没有错误即返回
    return $?
}

download_fastq() {
    local acc="$1"
    local pe url path
    if [[ ${#acc} -gt 11 || ${#acc} -lt 9 ]]; then
        echo "Error: Invalid accession lengthis '${acc}' (must be 9-11 characters)" >&2
        exit 1
    fi
    path=$(generate_path "$acc")

    # 下载md5校验值
    fetch_md5 "$acc"

    for pe in 1 2; do
        local outfile="${OUTPUT}/${acc}_${pe}.fastq.gz"
        if [[ "$METHOD" == "ftp" ]]; then
            local url="ftp://ftp.sra.ebi.ac.uk/vol1/fastq/${path}/${acc}_${pe}.fastq.gz"
            case "$FTP_TOOL" in
                aria2c)
                    aria2c -q --auto-file-renaming=false "$url" -d "$OUTPUT" || return 1
                    ;;
                curl)
                    (cd "$OUTPUT" && curl -sSLO "$url") || return 1
                    ;;
                wget)
                    wget -q -P "$OUTPUT" "$url" || return 1
                    ;;
                *)
                    echo "Error: Unknown FTP tool $FTP_TOOL"
                    return 1
                    ;;
            esac
        elif [[ "$METHOD" == "ascp" ]]; then
            local remote_file="/vol1/fastq/${path}/${acc}_${pe}.fastq.gz"
            # -k 3 可以校验已下载数据，尝试恢复下载并跳过已经下载完成的文件
            ascp -k 3 -QT -l 300m -P33001 -i "$SSH_FILE" "era-fasp@fasp.sra.ebi.ac.uk:$remote_file" "${OUTPUT}";
        else
            echo "Error: Wrong -m options, please use correct methods"
            exit 1
        fi
    done

    # 校验
    if verify_md5 "$acc"; then
        echo "$acc finally verified"
        return 0
    else
        echo "Error: Failed to download valid files for $acc"
        return 1
    fi
}

# 主函数
main() {
    # 处理长选项
    for arg in "$@"; do
        case "$arg" in
            --help) show_help ;;
            --version) show_version ;;
        esac
    done

    # 参数处理需要改进
    [[ $# -eq 0 ]] && show_help
    # 参数赋值
    local METHOD="ascp" JOBS=3 FTP_TOOL="aria2c" OUTPUT="output"
    local INPUT  

    # 需要增加长选项支持（--help/--version）
    while getopts ":m:i:d:j:t:hv" opt; do
        case $opt in
            h) show_help ;;
            v) show_version ;;
            m) METHOD="$OPTARG" ;;
            i) INPUT="$OPTARG" ;;
            d) OUTPUT="$OPTARG" ;;
            j) JOBS="$OPTARG" ;;
            t) FTP_TOOL="$OPTARG" ;;
            *) usage ;;
        esac
    done

    # 增强参数验证
    [[ -f "$INPUT" ]] || { echo "Error: Input file $INPUT not found"; exit 1; }
    [[ $JOBS =~ ^[0-9]+$ ]] || { echo "Error: Invalid jobs number"; exit 1; }
    [[ $JOBS -gt 3 ]] && JOBS=3

    # 下载前空间检查
    # 假设平均每个文件1GB，前期检索sra时过滤数据大小可以进行预估统计
    local required_space=$(($(wc -l < "$INPUT") * 2 * 1))
    if ! df -k --output=avail "$OUTPUT" | awk -v rs="$required_space" 'NR==2 {if ($1 < rs*1024) exit 1}'; then
        echo "Error: Not enough disk space in $OUTPUT"
        exit 1
    fi

    # 依赖软件检查
    case "$METHOD" in
        ftp) check_dependencies "$FTP_TOOL" ;;
        ascp) check_dependencies "ascp"; SSH_FILE=$(find_aspera_key) ;;
    esac

    mkdir -p "$OUTPUT"

    # 输出到环境变量，使其他脚本可以直接调用变量和函数
    export METHOD OUTPUT SSH_FILE FTP_TOOL
    export -f download_fastq generate_path check_dependencies fetch_md5 verify_md5

    # 并行下载
    xargs -P$JOBS -I{} bash -c '
        acc={}
        echo "Downloading $acc..."
        if download_fastq "$acc"; then
            echo "Finished $acc"
        else
            echo "Failed $acc"
        fi
    ' < <(grep -v '^#' "${INPUT}")
}

main "$@"