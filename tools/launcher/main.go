// Finans başlatıcısı: web sürümünü (build/web) kendi içinde taşır, bilgisayarda
// yerel bir sunucu açar ve tarayıcıda gösterir. Kullanıcının Flutter, Python
// veya başka bir şey kurmasına gerek yoktur.
//
// Veriler tarayıcıda adrese (http://127.0.0.1:8642) bağlı saklandığı için
// adres ve port sabittir; değişirse kullanıcı verilerini göremez.
package main

import (
	"embed"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"runtime"
	"time"
)

//go:embed all:web
var site embed.FS

const (
	addr = "127.0.0.1:8642"
	url  = "http://127.0.0.1:8642/"
)

func main() {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		// Port doluysa büyük olasılıkla uygulama zaten açık: sadece tarayıcıyı aç.
		fmt.Println("Finans zaten çalışıyor, tarayıcı açılıyor:", url)
		openBrowser(url)
		time.Sleep(2 * time.Second)
		return
	}

	root, err := fs.Sub(site, "web")
	if err != nil {
		fail(err)
	}
	files := http.FileServer(http.FS(root))
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Yeni sürüm kurulduğunda eski dosyalar önbellekten gelmesin.
		w.Header().Set("Cache-Control", "no-cache")
		files.ServeHTTP(w, r)
	})

	fmt.Println("==============================================")
	fmt.Println("  Finans çalışıyor:", url)
	fmt.Println("  Tarayıcı açılmazsa bu adresi kendiniz açın.")
	fmt.Println("  Kapatmak için bu pencereyi kapatın.")
	fmt.Println("==============================================")

	go func() {
		time.Sleep(500 * time.Millisecond)
		openBrowser(url)
	}()
	if err := http.Serve(ln, handler); err != nil {
		fail(err)
	}
}

func openBrowser(u string) {
	var cmd *exec.Cmd
	switch runtime.GOOS {
	case "windows":
		cmd = exec.Command("rundll32", "url.dll,FileProtocolHandler", u)
	case "darwin":
		cmd = exec.Command("open", u)
	default:
		cmd = exec.Command("xdg-open", u)
	}
	_ = cmd.Start()
}

func fail(err error) {
	fmt.Fprintln(os.Stderr, "Hata:", err)
	fmt.Println("Kapatmak için Enter'a basın.")
	fmt.Scanln()
	os.Exit(1)
}
