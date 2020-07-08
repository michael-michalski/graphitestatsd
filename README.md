# GraphiteStatsd
A docker image combining [carbon](https://github.com/graphite-project/carbon), [whisper](https://github.com/graphite-project/whisper), [graphite](https://github.com/graphite-project/graphite-web), [statsd](https://github.com/etsy/statsd) and nginx to create an all encompassing metric solution.

Check here, https://github.com/michael-michalski/graphitestatsd-encrypted, if your use case demands encryption: 

Reasons for using this image.

* Everything running under non root user(10001) and under group (10001)
* Lightweight, stripped for cloud use (130 mb).
* Using python3

## Building
ALPINE_VERSION=3.11.6 make build
That will result in:
michaelmichalski/graphitestatsd:3.11.6
