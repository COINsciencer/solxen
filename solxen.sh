
#!/bin/bash

# 确保以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请使用 'sudo -i' 切换到root用户，再运行此脚本。"
    exit 1
fi

function setup_environment() {
    # 更新系统和安装必要的软件包
    echo "更新系统软件包..."
    sudo apt update && sudo apt upgrade -y
    echo "安装必要的软件和依赖..."
    sudo apt install -y curl build-essential jq git libssl-dev pkg-config screen

    # 安装 Rust 和 Cargo
    echo "安装 Rust 和 Cargo..."
    curl https://sh.rustup.rs -sSf | sh -s -- -y
    source $HOME/.cargo/env

    # 安装 Solana CLI
    echo "安装 Solana CLI..."
    sh -c "$(curl -sSfL https://release.solana.com/v1.18.4/install)"

    # 检查 solana-keygen 是否在 PATH 中
    if ! command -v solana-keygen &> /dev/null; then
        echo "将 Solana CLI 添加到 PATH"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        export PATH="$HOME/.cargo/bin:$PATH"
    fi
}

function create_keypair() {
    # 生成 Solana 密钥对
    echo "创建 Solana 密钥对..."
    solana-keygen new --derivation-path m/44'/501'/0'/0' --force | tee solana-keygen-output.txt

    # 提示用户确认备份
    echo "请备份显示的助记词和私钥信息。"
    echo "请向pubkey充值sol资产，用于挖矿gas费用。"
    echo "备份完成后请输入 'yes' 继续："

    read -p "" 用户确认

    if [[ "$用户确认" != "yes" ]]; then
        echo "脚本终止。请备份信息后再运行脚本。"
        exit 1
    fi
}

function download_and_extract() {
    # 获取操作系统类型和架构
    OS=$(uname -s)
    ARCH=$(uname -m)

    # 确定下载 URL
    case "$OS" in
        "Darwin")
            if [ "$ARCH" = "x86_64" ]; then
                URL="https://github.com/mmc-98/solxen-tx/releases/download/mainnet-beta2/solxen-tx-mainnet-beta2-darwin-amd64.tar.gz"
            elif [ "$ARCH" = "arm64" ]; then
                URL="https://github.com/mmc-98/solxen-tx/releases/download/mainnet-beta2/solxen-tx-mainnet-beta2-darwin-arm64.tar.gz"
            else
                echo "不支持的架构: $ARCH"
                exit 1
            fi
            ;;
        "Linux")
            if [ "$ARCH" = "x86_64" ]; then
                URL="https://github.com/mmc-98/solxen-tx/releases/download/mainnet-beta2/solxen-tx-mainnet-beta2-linux-amd64.tar.gz"
            elif [ "$ARCH" = "aarch64" ]; then
                URL="https://github.com/mmc-98/solxen-tx/releases/download/mainnet-beta2/solxen-tx-mainnet-beta2-linux-arm64.tar.gz"
            else
                echo "不支持的架构: $ARCH"
                exit 1
            fi
            ;;
        *)
            echo "不支持的系统: $OS"
            exit 1
            ;;
    esac

    # 创建临时目录并下载文件
    TMP_DIR=$(mktemp -d)
    cd $TMP_DIR
    echo "下载文件 $URL..."
    curl -L -o solxen-tx.tar.gz $URL

    # 创建用户主目录的 solxen 文件夹
    INSTALL_DIR="$HOME/solxen"
    mkdir -p $INSTALL_DIR

    # 解压文件
    echo "解压文件 solxen-tx.tar.gz..."
    tar -xzvf solxen-tx.tar.gz -C $INSTALL_DIR
}

function configure_and_run() {
    # 检查文件是否存在
    CONFIG_FILE="$INSTALL_DIR/solxen-tx.yaml"
    if [ ! -f $CONFIG_FILE ]; then
        echo "错误: $CONFIG_FILE 不存在。"
        exit 1
    fi

    read -p "请输入SOL钱包助记词: " 助记词
    read -p "请输入同时运行的钱包数量（建议4）: " 钱包数量
    read -p "请输入优先级费用: " 费用
    read -p "请输入间隔时间（毫秒）: " 间隔时间
    read -p "请输入空投接收地址（需要ETH钱包地址）: " 以太坊地址
    read -p "请输入sol rpc地址: " rpc地址

    # 更新配置文件
    sed -i "s|Mnemonic:.*|Mnemonic: \"$助记词\"|" $CONFIG_FILE
    sed -i "s|Num:.*|Num: $钱包数量|" $CONFIG_FILE
    sed -i "s|Fee:.*|Fee: $费用|" $CONFIG_FILE
    sed -i "s|Time:.*|Time: $间隔时间|" $CONFIG_FILE
    sed -i "s|ToAddr:.*|ToAddr: $以太坊地址|" $CONFIG_FILE
    sed -i "s|Url:.*|Url: $rpc地址|" $CONFIG_FILE

    # 清理临时目录
    cd ~
    rm -rf $TMP_DIR

    # 启动 screen 会话并运行命令
    cd $INSTALL_DIR
    screen -dmS solxen bash -c './solxen-tx miner'

    echo "solxen-tx 安装和配置成功，请使用功能3查看运行情况"
}

function check_running_status() {
    screen -r solxen
}

function check_wallet_balance() {
    cd $INSTALL_DIR
    ./solxen-tx balance
}

function restart_miner() {
    screen -dmS solxen bash -c "cd $INSTALL_DIR && ./solxen-tx miner"
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "科学家旺仔 @howbuybtc 一键脚本"
        echo "youTube 币圈科学家旺仔 https://x.com/howbuybtc"
        echo "执行操作:"
        echo "1. 全新安装"
        echo "2. 已有SOL钱包安装"
        echo "3. 查看运行情况"
        echo "4. 查看钱包地址信息"
        echo "5. 适用于修改某些配置后，重新启动挖矿"
        read -p "请输入选项（1-5）: " 选项

        case $选项 in
            1) setup_environment && create_keypair && download_and_extract && configure_and_run ;;
            2) setup_environment && download_and_extract && configure_and_run ;;
            3) check_running_status ;;
            4) check_wallet_balance ;;
            5) restart_miner ;;
            *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
