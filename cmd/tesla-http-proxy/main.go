package main

import (
	"context"
	"encoding/base64"
	"flag"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

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

const (
	EnvHost    = "TESLA_HTTP_PROXY_HOST"
	EnvPort    = "TESLA_HTTP_PROXY_PORT"
	EnvTimeout = "TESLA_HTTP_PROXY_TIMEOUT"
	EnvVerbose = "TESLA_VERBOSE"
)

const nonLocalhostWarning = `
Do not listen on a network interface without adding client authentication. Unauthorized clients may
be used to create excessive traffic from your IP address to Tesla's servers, which Tesla may respond
to by rate limiting or blocking your connections.`

type HttpProxyConfig struct {
	keyFilename  string
	certFilename string
	verbose      bool
	host         string
	port         int
	timeout      time.Duration
}

var (
	httpConfig = &HttpProxyConfig{}
)

func init() {
	flag.BoolVar(&httpConfig.verbose, "verbose", false, "Enable verbose logging")
	flag.StringVar(&httpConfig.host, "host", "localhost", "Proxy server `hostname`")
	flag.IntVar(&httpConfig.port, "port", defaultPort, "`Port` to listen on")
	flag.DurationVar(&httpConfig.timeout, "timeout", proxy.DefaultTimeout, "Timeout interval when sending commands")
}

func Usage() {
	out := flag.CommandLine.Output()
	fmt.Fprintf(out, "Usage: %s [OPTION...]\n", os.Args[0])
	fmt.Fprintf(out, "\nA server that exposes a REST API for sending commands to Tesla vehicles")
	fmt.Fprintln(out, "")
	fmt.Fprintln(out, nonLocalhostWarning)
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
	config, err := cli.NewConfig(cli.FlagPrivateKey)

	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to load credential configuration: %s\n", err)
		os.Exit(1)
	}

	defer func() {
		if err != nil {
			fmt.Fprintf(os.Stderr, "Error: %s\n", err)
			os.Exit(1)
		}
	}()

	flag.Usage = Usage
	config.RegisterCommandLineFlags()
	flag.Parse()
	readFromEnvironment()
	config.ReadFromEnvironment()

	if httpConfig.verbose {
		log.SetLevel(log.LevelDebug)
	}

	if httpConfig.host != "localhost" {
		fmt.Fprintln(os.Stderr, nonLocalhostWarning)
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
	teslaProxy.Timeout = httpConfig.timeout
	addr := fmt.Sprintf("%s:%d", httpConfig.host, httpConfig.port)
	log.Info("Listening on %s", addr)

	wgHandler := NewWGTeslaProxy(teslaProxy)

	log.Error("Server stopped: %s", http.ListenAndServe(addr, wgHandler))
}

// readConfig applies configuration from environment variables.
// Values are not overwritten.
func readFromEnvironment() error {
	if httpConfig.host == "localhost" {
		host, ok := os.LookupEnv(EnvHost)
		if ok {
			httpConfig.host = host
		}
	}

	if !httpConfig.verbose {
		if verbose, ok := os.LookupEnv(EnvVerbose); ok {
			httpConfig.verbose = verbose != "false" && verbose != "0"
		}
	}

	var err error
	if httpConfig.port == defaultPort {
		if port, ok := os.LookupEnv(EnvPort); ok {
			httpConfig.port, err = strconv.Atoi(port)
			if err != nil {
				return fmt.Errorf("invalid port: %s", port)
			}
		}
	}

	if httpConfig.timeout == proxy.DefaultTimeout {
		if timeoutEnv, ok := os.LookupEnv(EnvTimeout); ok {
			httpConfig.timeout, err = time.ParseDuration(timeoutEnv)
			if err != nil {
				return fmt.Errorf("invalid timeout: %s", timeoutEnv)
			}
		}
	}

	return nil
}
