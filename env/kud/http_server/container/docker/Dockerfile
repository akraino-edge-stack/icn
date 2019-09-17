FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install apache2 wget systemd -y
RUN mkdir -p /var/www/icn/files
COPY ./icn.conf /etc/apache2/sites-available/icn.conf
COPY ./yui.tar.gz  /var/www/icn/files/
COPY ./index.html /var/www/icn/index.html
RUN a2ensite icn.conf
RUN a2dissite 000-default.conf
RUN ln -sf /storage /var/www/icn/files/storage
#RUN systemctl start apache2.service
#RUN systemctl enable apache2.service

EXPOSE 80
CMD apachectl -D FOREGROUND
#CMD ["bin/bash", "-ec", "while :; do echo '.'; sleep 3; done"]
