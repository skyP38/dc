FROM golang:1.19-alpine AS builder
WORKDIR /app
COPY go.mod ./
RUN go mod download
COPY . .
RUN go build -o auth-server .

FROM alpine:latest
RUN apk --no-cache add curl ca-certificates
WORKDIR /root/
COPY --from=builder /app/auth-server .
EXPOSE 8080
CMD ["./auth-server"]