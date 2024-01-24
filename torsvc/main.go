package main

import (
	"log"
	"net/http"
)

// We need a http server to serve our Tor requests
func main() {
	fs := http.FileServer(http.Dir("../public"))
	http.Handle("/", fs)
	log.Print("Starting server on http://localhost:8080")
	err := http.ListenAndServe(":8080", nil)
	if err != nil {
		log.Fatal(err)
	}
}
