FROM rakudo-star:2022.12-alpine

WORKDIR /app

RUN apk add openssl-dev git

# raku needs a home directory
RUN addgroup worker && \
    adduser worker -G worker -s /bin/nologin -D -u 1001

COPY main.raku main.raku

USER 1001

RUN zef install --force-install HTTP::Tiny && \
    zef install --force-install JSON::Unmarshal && \
    zef install --force-install Env && \
    zef install --force-install IO::Socket::SSL

ENTRYPOINT [ "rakudo", "--optimize=3", "--full-cleanup", "main.raku" ]
