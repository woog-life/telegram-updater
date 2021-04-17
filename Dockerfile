FROM thevlang/vlang:alpine AS build

WORKDIR /app

COPY . .

ENV VFLAGS="-cc gcc"
ENV PATH /app:$PATH

RUN apk add git

RUN v version

RUN git clone https://github.com/woog-life/vpkg
RUN cd vpkg && v -prod . && cd ..

RUN vpkg/vpkg install
RUN v -prod main.v

RUN ldd main

FROM scratch

COPY --from=build /lib/ld-musl-x86_64.so.1 /lib/
COPY --from=build /lib/libssl.so.1.1 /lib/
COPY --from=build /lib/libcrypto.so.1.1 /lib/

COPY --from=build /app/main /bin/

CMD ["main"]
