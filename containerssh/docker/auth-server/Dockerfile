FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o auth-server main.go

FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/auth-server .
EXPOSE 8080
CMD ["./auth-server"]
