package main

import (
	"flag"
	"log"
	"net/http"
)

// We need a http server to serve our Tor requests
func main() {
	flag.Parse()
	fs := http.FileServer(http.Dir("./public"))
	http.Handle("/", fs)
	log.Print("starting server on http://localhost:80\n")
	err := http.ListenAndServe(":80", nil)
	if err != nil {
		log.Fatal(err)
	}
}
