package main

import (
	"context"
	"encoding/base64"
	"flag"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/teslamotors/vehicle-command/internal/authentication"
	"github.com/teslamotors/vehicle-command/internal/log"
	"github.com/teslamotors/vehicle-command/pkg/cli"
	"github.com/teslamotors/vehicle-command/pkg/protocol"
	"github.com/teslamotors/vehicle-command/pkg/proxy"
)

const (
	cacheSize   = 10000 // Number of cached vehicle sessions
	defaultPort = 443
)

func Usage() {
	out := flag.CommandLine.Output()
	fmt.Fprintf(out, "Usage: %s [OPTION...]\n", os.Args[0])
	fmt.Fprintf(out, "\nA server that exposes a REST API for sending commands to Tesla vehicles")
	fmt.Fprintln(out, "")
	fmt.Fprintln(out, "Options:")
	flag.PrintDefaults()
}

type WGTeslaProxy struct {
	teslaProxy *proxy.Proxy
}

func NewWGTeslaProxy(proxy *proxy.Proxy) *WGTeslaProxy {
	return &WGTeslaProxy{teslaProxy: proxy}
}

// WGTeslaProxy is an http handler that wraps the tesla proxy
// this way we can inspect requests before passing on to the default tesla proxy
func (wgp *WGTeslaProxy) ServeHTTP(w http.ResponseWriter, req *http.Request) {

	if strings.HasPrefix(req.URL.Path, "/health") || req.URL.Path == "/" {
		// Health check; just return ok and don't spam logs
		w.WriteHeader(http.StatusOK)
		return
	}
	//pass request to tesla proxy
	wgp.teslaProxy.ServeHTTP(w, req)
}

func main() {
	// Command-line options
	var (
		verbose bool
		host    string
		port    int
	)
	config := cli.Config{Flags: cli.FlagPrivateKey}
	var err error
	defer func() {
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %s\n", err)
			os.Exit(1)
		}
	}()

	flag.BoolVar(&verbose, "verbose", false, "Enable verbose logging")
	flag.StringVar(&host, "host", "0.0.0.0", "Proxy server `hostname`")
	flag.IntVar(&port, "port", defaultPort, "`Port` to listen on")
	flag.Usage = Usage
	config.RegisterCommandLineFlags()
	flag.Parse()
	config.ReadFromEnvironment()

	if verbose {
		log.SetLevel(log.LevelDebug)
	}

	log.Debug("Loading secrets")

	var skey protocol.ECDHPrivateKey

	// read secret from environment variable
	teslaSecretValue := os.Getenv("TESLA_HTTP_PROXY_API_KEY")
	if teslaSecretValue != "" {
		decodedTeslaSecret, err := base64.StdEncoding.DecodeString(teslaSecretValue)
		if err != nil {
			log.Debug("Error decoding tesla secret value")
			return
		}
		skey, err = authentication.LoadECDHKeyFromString(string(decodedTeslaSecret))
		if err != nil {
			log.Debug("value: %s", strings.Replace(teslaSecretValue, "UQDQ", "9999", -1))
			log.Debug("Error converting pem secret to ECDHPrivateKey: %s", err.Error())
			return
		}
	} else {
		log.Debug("Error: no secret key for tesla found")
		return
	}

	log.Debug("Creating proxy")
	teslaProxy, err := proxy.New(context.Background(), skey, cacheSize)
	if err != nil {
		return
	}
	addr := fmt.Sprintf("%s:%d", host, port)
	log.Info("Listening on %s", addr)

	wgHandler := NewWGTeslaProxy(teslaProxy)

	log.Error("Server stopped: %s", http.ListenAndServe(addr, wgHandler))
}
