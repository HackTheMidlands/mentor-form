#!/bin/sh

apt update
apt install software-properties-common -y
add-apt-repository universe
add-apt-repository ppa:certbot/certbot
apt update

apt install nginx certbot python-certbot-nginx docker.io gcc g++ -y

export HOME=/root
curl https://install.meteor.com/ | sh

cd /root
git clone https://github.com/HackTheMidlands/mentor-form.git
cd mentor-form
mv ../config.json private/config.json

meteor build --directory ./build/ --allow-superuser
cd build/bundle
(cd programs/server; meteor npm install node-gyp; sudo meteor npm install)

docker run -d --name helpq-mongo --restart always -e MONGO_INITDB_ROOT_USERNAME=root -e MONGO_INITDB_ROOT_PASSWORD=password -p 27017:27017 mongo 
sleep 10

export PORT=8000
export MONGO_URL='mongodb://root:password@localhost:27017/admin'
export ROOT_URL='http://localhost:8000'
meteor node main.js &

rm /etc/nginx/sites-enabled/default
mv /root/helpq.nginx /etc/nginx/sites-available/helpq
ln -s /etc/nginx/sites-available/helpq /etc/nginx/sites-enabled/
echo "client_max_body_size 25M;" > /etc/nginx/conf.d/client-size.conf
sudo systemctl restart nginx

certbot --non-interactive --nginx --redirect --domains help.hackthemidlands.com --agree-tos --register-unsafely-without-email
sudo systemctl restart nginx
