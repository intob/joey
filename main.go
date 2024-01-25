package main

import (
	"log"
	"net/http"
	"os"
)

// We need a http server to serve our Tor requests
func main() {
	fs := http.FileServer(http.Dir("./public"))
	http.Handle("/", fs)
	port := os.Getenv("PORT")
	log.Printf("Starting server on http://localhost:%s", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		log.Fatal(err)
	}
}
