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
func ServicesGet(w http.ResponseWriter, r *http.Request) {
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
}

// [END functions_helloworld_get]
