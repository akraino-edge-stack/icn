# 1. build and nstall 
# we can put all file to files folder which need to be downloaded
# 1.1 For offline host Http server
sh http_setup.sh

# 1.2 For offline container http server 
docker build -t haibinhu/httpd .
docker run -it -p80:80 haibinhu/httpd

# 2. test download package
# 2.1 for host
wget http://<host-ip>/files/yui.tar.gz

# 2.2 for container
wget http://<container-ip>/files/yui.tar.gz
