package kv

import (
	"strings"

	"github.com/hidal-go/hidalgo/kv"

	"github.com/cayleygraph/cayley/graph"
)

func init() {
	for _, r := range kv.List() {
		switch r.Name {
		case "bolt":
			panic("Legacy 'bolt' backend can no longer be compiled in") // Replaced with bbolt
		case "bbolt":
			continue // legacy: register manually; see comments in the bolt package
		}
		r := r
		reg := Registration{
			InitFunc: func(s string, options graph.Options) (kv.KV, error) {
				return r.OpenPath(s)
			},
			NewFunc: func(s string, options graph.Options) (kv.KV, error) {
				return r.OpenPath(s)
			},
			IsPersistent: !r.Volatile,
		}
		name := r.Name
		// override names for backward compatibility
		// names are also nicer without the "flat." prefix
		if strings.HasPrefix(name, "flat.") && !graph.IsRegistered(name[5:]) {
			name = name[5:]
		}
		Register(name, reg)
	}
}
