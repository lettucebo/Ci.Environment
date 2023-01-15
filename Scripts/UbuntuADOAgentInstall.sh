sudo apt-get update && apt-get upgrade -y

wget https://dot.net/v1/dotnet-install.sh
sudo chmod +x ./dotnet-install.sh

env DOTNET_ROOT=/usr/share/dotnet
env PATH=$PATH:/usr/share/dotnet
export PATH=$PATH:/usr/share/dotnet

sudo ./dotnet-install.sh --install-dir /usr/share/dotnet --channel 7.0
sudo ./dotnet-install.sh --install-dir /usr/share/dotnet --channel 6.0
sudo ./dotnet-install.sh --install-dir /usr/share/dotnet --channel 5.0
sudo ./dotnet-install.sh --install-dir /usr/share/dotnet --channel 3.1
sudo ./dotnet-install.sh --install-dir /usr/share/dotnet --channel 2.1

dotnet --list-sdks

###

wget -c http://security.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
wget -c http://security.ubuntu.com/ubuntu/pool/main/o/openssl/openssl_1.1.1f-1ubuntu2.16_amd64.deb
sudo chown -Rv _apt:root libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
sudo chown -Rv _apt:root openssl_1.1.1f-1ubuntu2.16_amd64.deb
sudo apt -y install ./libssl1.1_1.1.1f-1ubuntu2.16_amd64.deb
sudo apt -y --allow-downgrades install ./openssl_1.1.1f-1ubuntu2.16_amd64.deb


wget https://vstsagentpackage.azureedge.net/agent/2.214.1/vsts-agent-linux-x64-2.214.1.tar.gz
mkdir adoagent && cd adoagent
tar zxvf ../vsts-agent-linux-x64-2.214.1.tar.gz

./config.sh

#########

sudo ./svc.sh install [username]
sudo ./svc.sh start
