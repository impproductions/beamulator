FROM golang:1.23

WORKDIR /app

COPY . .

RUN mkdir -p build && go build -o build/server ./...
RUN chmod +x /app/build/server

CMD ["/app/build/server"]
