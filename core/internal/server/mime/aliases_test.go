package mime

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestMimeAliasesBothWays(t *testing.T) {
	system := t.TempDir()
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("XDG_DATA_DIRS", system)
	dir := filepath.Join(system, "mime")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		t.Fatal(err)
	}
	aliases := "application/x-cd-image application/vnd.efi.iso\napplication/x-iso9660-image application/vnd.efi.iso\ntext/x-other text/plain\n"
	if err := os.WriteFile(filepath.Join(dir, "aliases"), []byte(aliases), 0o644); err != nil {
		t.Fatal(err)
	}

	// The canonical name reaches its old names; an old name reaches the canonical one first, then its siblings.
	if got := mimeAliases("application/vnd.efi.iso"); !slices.Equal(got, []string{"application/x-cd-image", "application/x-iso9660-image"}) {
		t.Fatalf("canonical: %v", got)
	}
	if got := mimeAliases("application/x-cd-image"); !slices.Equal(got, []string{"application/vnd.efi.iso", "application/x-iso9660-image"}) {
		t.Fatalf("alias: %v", got)
	}
	if got := mimeAliases("image/png"); len(got) != 0 {
		t.Fatalf("none: %v", got)
	}
}
