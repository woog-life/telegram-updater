FROM rakudo-star:2022.07-alpine

WORKDIR /app

COPY main.raku main.raku

RUN zef install HTTP::Tiny && \
    zef install JSON::Unmarshal && \
    zef install IO::Socket::SSL && \
    zef install Env

ENTRYPOINT [ "rakudo", "main.raku" ]
