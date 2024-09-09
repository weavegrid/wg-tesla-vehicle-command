# Build Stage
# First pull Golang image
FROM golang:1.20-alpine AS build-env

# Set environment variable
ENV APP_NAME=tesla-http-proxy
ENV CMD_PATH=cmd/tesla-http-proxy/main.go

# Copy application data into image
COPY . $GOPATH/src/$APP_NAME
WORKDIR $GOPATH/src/$APP_NAME

# Build application
RUN go mod download
RUN CGO_ENABLED=0 go build -v -o /$APP_NAME $GOPATH/src/$APP_NAME/$CMD_PATH

ENV TESLA_KEY_FILE=private_key.pem

# Run the application
CMD [ "/tesla-http-proxy", "-port", "8080", "-verbose", "true"]