package mime

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
)

// mimeAliases lists the other names of a type in shared-mime-info's aliases files, its canonical name first: an app
// may declare only an old name (application/x-cd-image) of a file's type (application/vnd.efi.iso).
func mimeAliases(mimeType string) []string {
	canonical := mimeType
	var pairs [][2]string
	for _, dir := range mimeDataDirs() {
		data, err := os.ReadFile(filepath.Join(dir, "aliases"))
		if err != nil {
			continue
		}
		for line := range strings.Lines(string(data)) {
			f := strings.Fields(line)
			if len(f) != 2 || strings.HasPrefix(f[0], "#") {
				continue
			}
			pairs = append(pairs, [2]string{f[0], f[1]})
			if f[0] == mimeType {
				canonical = f[1]
			}
		}
	}
	var out []string
	add := func(m string) {
		if m != mimeType && !slices.Contains(out, m) {
			out = append(out, m)
		}
	}
	add(canonical)
	for _, p := range pairs {
		if p[1] == canonical {
			add(p[0])
		}
	}
	return out
}
