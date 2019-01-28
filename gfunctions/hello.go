// Copyright 2018 Google LLC. All rights reserved.
// Use of this source code is governed by the Apache 2.0
// license that can be found in the LICENSE file.

// [START functions_helloworld_get]

// Package helloworld provides a set of Cloud Function samples.
package helloworld

import (
        "io"
        "log"
        "fmt"
        "strings"
        "net/http"
        "encoding/json"
)

type Service map[string]interface{}

// HelloGet is an HTTP Cloud Function.
func HelloGet(w http.ResponseWriter, r *http.Request) {
  var myMapSlice []Service
  //https://golang.org/pkg/encoding/json/
  myMapSlice = append(myMapSlice,
    Service{"id": 1, "Name": "Wedding"},
    Service{"id": 2, "Name": "Birthday"},
   	Service{"id": 3, "Name": "Conference"})

  b, err := json.Marshal(myMapSlice)
  if err != nil {
    fmt.Fprintln(w,"error:", err)
  }
  fmt.Fprint(w, string(b))

  const jsonStream = `
	{"Name": "Ed", "Text": "Knock knock."}
	{"Name": "Sam", "Text": "Who's there?"}
	{"Name": "Ed", "Text": "Go fmt."}
	{"Name": "Sam", "Text": "Go fmt who?"}
	{"Name": "Ed", "Text": "Go fmt yourself!"}
`
	type Message struct {
		Name, Text string
	}
	dec := json.NewDecoder(strings.NewReader(jsonStream))
	for {
		var m Message
		if err := dec.Decode(&m); err == io.EOF {
			break
		} else if err != nil {
			log.Fatal(err)
		}
    //fmt.Fprintf(w,"%s: %s\n", m.Name, m.Text)
	}
}

// [END functions_helloworld_get]
