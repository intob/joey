package main

import (
	"flag"
	"log"
	"net/http"
)

// We need a http server to serve our Tor requests
func main() {
	flag.Parse()
	dir := flag.Arg(0)
	fs := http.FileServer(http.Dir(dir))
	log.Printf("serving dir: %s", dir)
	http.Handle("/", fs)
	log.Print("starting server on http://localhost:80\n")
	err := http.ListenAndServe(":80", nil)
	if err != nil {
		log.Fatal(err)
	}
}
