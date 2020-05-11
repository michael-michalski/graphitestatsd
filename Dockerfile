ARG ALPINE_VERSION=3.11.6

FROM alpine:$ALPINE_VERSION

RUN apk add --update --no-cache nginx nodejs git gcc ca-certificates python3-dev py3-pip musl-dev libffi-dev cairo supervisor &&\
        apk upgrade --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/main gcc sqlite-libs           &&\
        pip3 install -U pip pytz gunicorn six wheel                                                                  &&\
        addgroup -g 10001 -S graphite                                                                                &&\
        adduser -u 10001 -S graphite -G graphite

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
        && pip3 --no-cache-dir install . \
        && python3 setup.py install \
        && pip3 --no-cache-dir install -r requirements.txt \
        && python3 check-dependencies.py

RUN git clone -b v0.8.6 --depth=1 https://github.com/etsy/statsd.git /opt/statsd

# Configure StatsD
ADD ./graphite/statsd/config.js /opt/statsd/config.js

# Configure Whisper, Carbon and Graphite-Web
ADD     ./graphite/graphite/local_settings.py /opt/graphite/webapp/graphite/local_settings.py
ADD     ./graphite/graphite/carbon.conf /opt/graphite/conf/carbon.conf
ADD     ./graphite/graphite/storage-schemas.conf /opt/graphite/conf/storage-schemas.conf
ADD     ./graphite/graphite/storage-aggregation.conf /opt/graphite/conf/storage-aggregation.conf
RUN     mkdir -p /opt/graphite/storage/whisper                                                                       &&\
        mkdir -p /opt/graphite/storage/log/webapp                                                                    &&\
        touch /opt/graphite/storage/graphite.db /opt/graphite/storage/index                                          &&\
        chown -R graphite /opt/graphite/storage                                                                      &&\
        chmod 0775 /opt/graphite/storage /opt/graphite/storage/whisper                                               &&\
        chmod 0664 /opt/graphite/storage/graphite.db                                                                 &&\
        cp /src/graphite-web/webapp/manage.py /opt/graphite/webapp                                                   &&\
        cd /opt/graphite/webapp/ && python3 manage.py migrate --run-syncdb --noinput

# Configure nginx and supervisord
ADD ./graphite/nginx/nginx.conf /etc/nginx/nginx.conf
ADD ./graphite/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN chown -R graphite:graphite /opt/graphite && chmod -R g+w /opt/graphite

RUN chown -R graphite:graphite /run && chmod -R 775 /run \
        && chown -R graphite:graphite /var/lib/nginx && chmod -R 775 /var/lib/nginx \
        && rm -rf /src

WORKDIR /var/run/supervisor

# ADD nginx-selfsigned.crt /etc/ssl/certs/nginx-selfsigned.crt
# ADD nginx-selfsigned.key /etc/ssl/private/nginx-selfsigned.key

# RUN chown graphite /etc/ssl/certs/nginx-selfsigned.crt && \
#     chown graphite /etc/ssl/private/nginx-selfsigned.key

# RUN chgrp graphite /etc/ssl/certs/nginx-selfsigned.crt && \
#     chgrp graphite /etc/ssl/private/nginx-selfsigned.key

# Cleanup Compile Dependencies
RUN scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/bin | xargs -r strip --strip-all \
  && scanelf --nobanner -E ET_EXEC -BF '%F' --recursive /usr/lib/python3.8 | xargs -r strip --strip-all \
  && scanelf --nobanner -E ET_DYN -BF '%F' --recursive /usr/lib/python3.8  | xargs -r strip --strip-unneeded \
  && find /usr/lib/python3.8 -name '__pycache__' -delete -print -o -name '*.pyc' -delete -print \
  && apk del --no-cache git gcc python3-dev musl-dev libffi-dev py3-pip scanelf

ENV STATSD_INTERFACE udp

USER graphite
CMD ["/usr/bin/supervisord", "--nodaemon", "--configuration", "/etc/supervisor/conf.d/supervisord.conf"]
