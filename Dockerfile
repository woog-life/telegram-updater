FROM thevlang/vlang:alpine AS build

WORKDIR /app

COPY . .

ENV VFLAGS="-cc gcc"

RUN apk add --no-cache git

RUN ./vpkg install
RUN v -prod main.v

RUN v version
RUN ldd main

FROM scratch

COPY --from=build /lib/ld-musl-x86_64.so.1 /lib/
COPY --from=build /lib/libssl.so.1.1 /lib/
COPY --from=build /lib/libcrypto.so.1.1 /lib/

COPY --from=build /app/main /bin/

CMD ["main"]
