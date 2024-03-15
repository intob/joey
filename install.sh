# Install script
sudo apt-get update && sudo apt-get upgrade -y

sudo apt-get install -y golang-go tor git

CGO_ENABLED=1 go install -tags extended github.com/gohugoio/hugo@latest

git clone https://github.com/intob/joeyinnes.git

sudo systemctl enable tor
sudo systemctl start tor
sudo systemctl status tor | cat
echo "Tor installation and setup completed!"

git --version
go version
tor --version
hugo version