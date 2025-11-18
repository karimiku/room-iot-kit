FROM golang:1.25.1

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .

RUN go build -o api main.go

ENV PORT=8080
EXPOSE 8080

CMD ["./api"]