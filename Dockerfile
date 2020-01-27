ARG ALPINE_VERSION

FROM alpine:$ALPINE_VERSION

RUN apk add --update --no-cache nginx nodejs nodejs-npm git curl wget gcc ca-certificates \
                                    python3-dev py3-pip musl-dev libffi-dev cairo supervisor bash                    &&\
        apk --no-cache add ca-certificates wget                                                                      &&\
        npm config set unsafe-perm tru                                                                               &&\
        wget -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub                  &&\
        wget https://github.com/sgerrand/alpine-pkg-glibc/releases/download/2.28-r0/glibc-2.28-r0.apk                &&\
        apk add glibc-2.28-r0.apk                                                                                    &&\
        rm glibc-2.28-r0.apk                                                                                         &&\
        adduser -D -g 0 graphite                                                                                     &&\
        pip3 install -U pip pytz gunicorn six wheel                                                                  &&\
        npm install -g wizzy                                                                                         &&\
        npm cache clean --force

# Checkout the master branches of Graphite, Carbon and Whisper and install from there
RUN mkdir /src \
        && git clone -b master https://github.com/graphite-project/whisper.git /src/whisper \
        && cd /src/whisper \
        && pip3 install . \
        && python3 setup.py install \
        && git clone --depth=1 --branch master https://github.com/graphite-project/carbon.git /src/carbon \
        && cd /src/carbon \
        && pip3 install . \
        && python3 setup.py install \
        && git clone --depth=1 --branch master https://github.com/graphite-project/graphite-web.git /src/graphite-web \
        && cd /src/graphite-web \
        && pip3 install . \
        && python3 setup.py install \
        && pip3 install -r requirements.txt \
        && python3 check-dependencies.py

RUN git clone -b v0.8.4 --depth=1 https://github.com/etsy/statsd.git /opt/statsd

# Cleanup Compile Dependencies
RUN apk del --no-cache git gcc python-dev musl-dev libffi-dev npm py-pip wget nodejs-npm

# Configure StatsD
ADD ./graphite/statsd/config.js /opt/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /opt/graphite/storage/whisper                                                                       &&\
        mkdir -p /opt/graphite/storage/log/webapp                                                                    &&\
        touch /opt/graphite/storage/log/webapp/info.log                                                              &&\
        touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index                                          &&\
        chown -R graphite /opt/graphite/storage                                                                      &&\
        chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper                                               &&\
        chmod 0664 /opt/graphite/storage/graphite.db                                                                 &&\
        cp /src/graphite-web/webapp/manage.py /opt/graphite/webapp                                                   &&\
        cd /opt/graphite/webapp/ && python3 manage.py migrate --run-syncdb --noinput

# Configure nginx and supervisord
ADD ./graphite/nginx/nginx.conf /etc/nginx/nginx.conf
RUN mkdir /var/log/supervisor && mkdir -p /var/tmp/nginx
ADD ./graphite/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD graphite/logrotate.d/graphitestatsd /etc/logrotate.d/graphitestatsd

RUN chown -R graphite:0 /opt/graphite && chmod -R g+w /opt/graphite

RUN touch /var/log/supervisor/supervisord.log \
  && touch /var/log/supervisord.pid \
  && chown -R graphite:0 /var/log && chmod -R 775 /var/log \
  && chmod -R 775 /var/log/supervisor/supervisord.log \
  && chown -R graphite:0 /run && chmod -R 775 /run \
  && chown -R graphite:0 /var/lib/nginx && chmod -R 775 /var/lib/nginx \
  && chown -R graphite:0 /var/tmp/nginx && chmod -R 775 /var/tmp/nginx \
  && sed -i.bak 's/^user/#user/' /etc/nginx/nginx.conf \
  && rm -rf /src

WORKDIR /var/log/supervisor

ENV STATSD_INTERFACE udp

USER graphite
CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]
