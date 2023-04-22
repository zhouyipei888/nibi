#!/bin/bash

# Install Go
sudo rm -rf /usr/local/go;
curl https://dl.google.com/go/go1.19.2.linux-amd64.tar.gz | sudo tar -C/usr/local -zxvf - ;
cat <<'EOF' >>$HOME/.profile
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export GO111MODULE=on
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
EOF
source $HOME/.profile

# Install required packages
sudo apt-get update -y 
sudo apt-get install curl build-essential wget jq git -y;

# Install nibiru Node
cd
git clone https://github.com/NibiruChain/nibiru
cd nibiru
git checkout  v0.19.2
make install

# 初始化节点
read -e -p "请输入验证者名字: " moniker
nibid init $moniker --chain-id=nibiru-itn-1
nibid config chain-id nibiru-itn-1

# 下载Genesis 文件
curl -s https://rpc.itn-1.nibiru.fi/genesis | jq -r .result.genesis >  ~/.nibid/config/genesis.json

# 设置peer和seed
PEERS="df8596fa04abeff1d15b79570ff8c3eba85ed87a@35.185.8.9:26656,4a81486786a7c744691dc500360efcdaf22f0840@15.235.46.50:26656,c709cad9e11b315644fe8f1d2e90c03c5cba685c@34.91.8.241:26656,930b1eb3f0e57b97574ed44cb53b69fb65722786@144.76.30.36:15662,ad002a4592e7bcdfff31eedd8cee7763b39601e7@65.109.122.105:36656"
seeds="a431d3d1b451629a21799963d9eb10d83e261d2c@seed-1.itn-1.nibiru.fi:26656,6a78a2a5f19c93661a493ecbe69afc72b5c54117@seed-2.itn-1.nibiru.fi:26656"
sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.nibid/config/config.toml
sed -i.bak -e "s/^seeds *=.*/seeds = \"$seeds\"/" ~/.nibid/config/config.toml

# Pruning设置
pruning="custom" && \
pruning_keep_recent="100" && \
pruning_keep_every="0" && \
pruning_interval="10" && \
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.nibid/config/app.toml && \
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.nibid/config/app.toml && \
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.nibid/config/app.toml && \
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.nibid/config/app.toml

# 下载addrbook
wget -O $HOME/.nibid/config/addrbook.json https://snapshot.silentvalidator.com/testnet/nibiru/addrbook.json

# 启动节点
sudo tee <<EOF >/dev/null /etc/systemd/system/nibid.service
[Unit]
Description=nibid daemon
After=network-online.target
[Service]
User=$USER
ExecStart=$(which nibid) start
Restart=on-failure
RestartSec=3
LimitNOFILE=10000
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload && \
sudo systemctl enable nibid && \
sudo systemctl start nibid

# 使用Snapshot同步
cd $HOME
sudo apt install snapd -y
sudo snap install lz4
sudo systemctl stop nibid
nibid tendermint unsafe-reset-all --home $HOME/.nibid --keep-addr-book
wget -O nibiru.tar.lz4 https://snapshot.silentvalidator.com/testnet/nibiru/nibiru-2023-03-07T07%3A24.tar.lz4  --inet4-only
lz4 -c -d nibiru.tar.lz4  | tar -x -C $HOME/.nibid
sudo systemctl start nibid
