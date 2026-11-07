#!/bin/sh
# The island shelf's actions on kept files (IslandShelf.command). A new file lands next to its source under a free name,
# never over an existing one, and its path is printed for the shelf to keep. Local tools only, nothing on the network.
# usage: island-shelf.sh <verb> [arg] -- <file>...
set -u
verb=$1
shift
arg=""
if [ "${1:-}" != "--" ]; then
    arg=$1
    shift
fi
[ "${1:-}" = "--" ] && shift
case "$verb" in
newtext | paste) ;;
*) [ $# -gt 0 ] || exit 2 ;;
esac
# Only absolute paths reach a tool: a name can never read as an option or a URL scheme.
for f; do
    case "$f" in /*) ;; *) exit 2 ;; esac
done
# The quick look's readers: 4 says the file is gone (deleted while looked at).
case "$verb" in content | list | info | tags) [ -e "$1" ] || exit 4 ;; esac

has() { command -v "$1" >/dev/null 2>&1; }
dir() { d=${1%/*}; printf '%s' "${d:-/}"; }
base() { printf '%s' "${1##*/}"; }
# The name without its last extension ("a.tar.gz" keeps "a.tar"); a dotfile or a folder keeps its whole name.
stem() { b=$(base "$1"); case "$b" in ?*.*) printf '%s' "${b%.*}" ;; *) printf '%s' "$b" ;; esac; }
ext() { b=$(base "$1"); case "$b" in ?*.*) printf '%s' "${b##*.}" ;; esac; }
# A path that does not exist yet: "stem.ext", then "stem (2).ext"...
# shortcut: another program could take the name between this check and the write; only this shell writes there.
free() {
    n="$1/$2${3:+.$3}"
    i=2
    while [ -e "$n" ] || [ -L "$n" ]; do
        n="$1/$2 ($i)${3:+.$3}"
        i=$((i + 1))
    done
    printf '%s' "$n"
}
done_() { printf '%s\n' "$1"; }
ff() { ffmpeg -nostdin -loglevel error "$@"; }
# New files with no source beside them (a new text, a paste) go to the Documents folder.
docs() { d=$(xdg-user-dir DOCUMENTS 2>/dev/null); [ -d "$d" ] || d=$HOME; printf '%s' "$d"; }
# LibreOffice on an untrusted document: its own throwaway profile (never the owner's, which may be open), macros off,
# remote links blocked.
office() {
    ot=$(mktemp -d) || return 1
    mkdir -p "$ot/profile/user" "$ot/out"
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>' \
        '<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema">' \
        '<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="MacroSecurityLevel" oor:op="fuse"><value>3</value></prop></item>' \
        '<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="DisableMacrosExecution" oor:op="fuse"><value>true</value></prop></item>' \
        '<item oor:path="/org.openoffice.Office.Common/Security/Scripting"><prop oor:name="BlockUntrustedRefererLinks" oor:op="fuse"><value>true</value></prop></item>' \
        '</oor:items>' >"$ot/profile/user/registrymodifications.xcu"
    timeout 90 soffice "-env:UserInstallation=file://$ot/profile" --headless --norestore --nolockcheck --nologo --nodefault \
        --convert-to "$1" --outdir "$ot/out" "$2" >/dev/null 2>&1
    or=1
    for of in "$ot/out"/*; do
        [ -f "$of" ] && mv -n -- "$of" "$3" && [ -e "$3" ] && or=0
    done
    rm -rf -- "$ot"
    return $or
}

case "$verb" in
to)
    # "<tool>:<format>" from IslandShelf.formats; the result lands beside its source under a free name.
    case "$arg" in
    magick:* | ffmpeg:* | soffice:* | pandoc:*) ;;
    *) exit 2 ;;
    esac
    tool=${arg%%:*}
    fmt=${arg#*:}
    case "$fmt" in "" | *[!a-z0-9]*) exit 2 ;; esac
    for f; do
        o=$(free "$(dir "$f")" "$(stem "$f")" "$fmt")
        case "$tool" in
        magick)
            case "$f" in
            *.pdf | *.PDF) magick -density 110 "$f[0]" "$o" ;;
            *) magick "$f" "$o" ;;
            esac ;;
        ffmpeg)
            # "file:" so a name with a colon never reads as a protocol.
            case "$fmt" in
            gif) ff -t 10 -i "file:$f" -vf "fps=12,scale=480:-1:flags=lanczos" "file:$o" ;;
            mp3 | ogg | wav | flac) ff -i "file:$f" -vn "file:$o" ;;
            *) ff -i "file:$f" "file:$o" ;;
            esac ;;
        soffice) office "$fmt" "$f" "$o" ;;
        pandoc) pandoc --sandbox -o "$o" "$f" ;;
        esac && [ -s "$o" ] && done_ "$o" && continue
        [ -e "$o" ] && [ ! -s "$o" ] && rm -f -- "$o"
        exit 1
    done ;;
trash)
    for f; do { gio trash -- "$f" && done_ "$f"; } || exit 1; done ;;
untrash)
    # Back from the trash to where it was, never over a file there now (gio refuses without --force).
    for f; do
        u=$(gio trash --list 2>/dev/null | P="$f" awk -F '\t' '$2 == ENVIRON["P"] { u = $1 } END { print u }')
        [ -n "$u" ] || exit 4
        { gio trash --restore "$u" && done_ "$f"; } || exit 1
    done ;;
rename)
    # One file, a new name in the same folder (one segment), never over another file.
    [ $# -eq 1 ] || exit 2
    case "$arg" in "" | . | .. | */*) exit 2 ;; esac
    t="$(dir "$1")/$arg"
    { [ -e "$t" ] || [ -L "$t" ]; } && exit 5
    mv -n -T -- "$1" "$t" && [ -e "$t" ] && [ ! -e "$1" ] && printf '%s\t%s\n' "$1" "$t" ;;
newtext)
    d=${arg:-$(docs)}
    o=$(free "$d" "untitled" txt)
    (set -C && : >"$o") && done_ "$o" ;;
paste)
    # Files on the clipboard come back as links ("uris" then the list); a picture or text becomes a new file.
    types=$(wl-paste -l 2>/dev/null) || exit 3
    d=${arg:-$(docs)}
    case "$types" in
    *text/uri-list*) echo uris; wl-paste -n -t text/uri-list ;;
    *image/png*) o=$(free "$d" "pasted" png); (set -C && wl-paste -t image/png >"$o") && done_ "$o" ;;
    *text/plain*) o=$(free "$d" "pasted" txt); (set -C && wl-paste -n -t text/plain >"$o") && done_ "$o" ;;
    *) exit 3 ;;
    esac ;;
convert)
    case "$arg" in "" | *[!a-z0-9]*) exit 2 ;; esac
    for f; do
        o=$(free "$(dir "$f")" "$(stem "$f")" "$arg")
        { magick "$f" "$o" && done_ "$o"; } || exit 1
    done ;;
shrink-image)
    for f; do
        o=$(free "$(dir "$f")" "$(stem "$f")-small" "$(ext "$f")")
        { magick "$f" -resize '50%' -quality 85 "$o" && done_ "$o"; } || exit 1
    done ;;
rotate)
    for f; do
        o=$(free "$(dir "$f")" "$(stem "$f")-rotated" "$(ext "$f")")
        { magick "$f" -rotate 90 "$o" && done_ "$o"; } || exit 1
    done ;;
sheet)
    o=$(free "$(dir "$1")" "contact-sheet" png)
    magick montage "$@" -tile 4x -geometry '320x320+8+8' "$o" && done_ "$o" ;;
images-pdf)
    o=$(free "$(dir "$1")" "$(stem "$1")" pdf)
    # img2pdf refuses some pictures (16 bit with alpha) and leaves an empty file: that free name was ours, retry with magick.
    { has img2pdf && img2pdf -o "$o" -- "$@" 2>/dev/null; } || { rm -f -- "$o"; magick "$@" "$o"; } && done_ "$o" ;;
frame)
    o=$(free "$(dir "$1")" "$(stem "$1")-frame" png)
    ff -ss 1 -i "$1" -frames:v 1 "$o" && done_ "$o" ;;
shrink-video)
    o=$(free "$(dir "$1")" "$(stem "$1")-small" mp4)
    ff -i "$1" -vf "scale='min(1280,iw)':-2" -c:v libx264 -crf 28 -preset veryfast -c:a aac -b:a 96k "$o" && done_ "$o" ;;
gif)
    o=$(free "$(dir "$1")" "$(stem "$1")" gif)
    ff -t 10 -i "$1" -vf "fps=12,scale=480:-1:flags=lanczos" "$o" && done_ "$o" ;;
mute)
    o=$(free "$(dir "$1")" "$(stem "$1")-muted" "$(ext "$1")")
    ff -i "$1" -c copy -an "$o" && done_ "$o" ;;
mp3)
    o=$(free "$(dir "$1")" "$(stem "$1")" mp3)
    ff -i "$1" -vn -codec:a libmp3lame -q:a 2 "$o" && done_ "$o" ;;
shrink-pdf)
    for f; do
        o=$(free "$(dir "$f")" "$(stem "$f")-small" pdf)
        { gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -sOutputFile="$o" "$f" && done_ "$o"; } || exit 1
    done ;;
pdf-images)
    d=$(free "$(dir "$1")" "$(stem "$1")-pages" "")
    mkdir -- "$d" && pdftoppm -png -r 110 "$1" "$d/page" && done_ "$d" ;;
merge-pdf)
    o=$(free "$(dir "$1")" "merged" pdf)
    if has qpdf; then qpdf --empty --pages "$@" -- "$o"
    elif has pdfunite; then pdfunite "$@" "$o"
    else gs -q -dNOPAUSE -dBATCH -dSAFER -sDEVICE=pdfwrite -sOutputFile="$o" "$@"; fi && done_ "$o" ;;
zip)
    if [ $# -eq 1 ]; then name=$(stem "$1"); else name=Archive; fi
    o=$(free "$(dir "$1")" "$name" zip)
    if has zip; then
        for f; do
            (cd -- "$(dir "$f")" && zip -r -q -y "$o" "$(base "$f")") || exit 1
        done
    else
        # 7z stores an absolute path under its last part, as zip does from its folder.
        7z a -tzip -bd "$o" "$@" >/dev/null || exit 1
    fi
    done_ "$o" ;;
extract)
    # Into a new folder, never over the files around; bsdtar, 7z, unzip and tar refuse names that climb out of it.
    for f; do
        name=$(stem "$f")
        name=${name%.tar}
        d=$(free "${arg:-$(dir "$f")}" "$name" "")
        mkdir -- "$d" || exit 1
        if has bsdtar; then bsdtar -xf "$f" -C "$d"
        elif has 7z; then 7z x -bd -y -o"$d" -- "$f" >/dev/null
        else
            case "$f" in
            *.zip) unzip -q "$f" -d "$d" ;;
            *) tar -xf "$f" -C "$d" ;;
            esac
        fi || { rmdir -- "$d" 2>/dev/null; exit 1; }
        done_ "$d"
    done ;;
ocr) tesseract "$1" stdout 2>/dev/null ;;
pdf-text) pdftotext -layout "$1" - ;;
content) head -c 1048576 -- "$1" ;;
sha) sha256sum -- "$1" | cut -d' ' -f1 ;;
verify)
    # A sum file beside the image (Fedora's CHECKSUM, SHA256SUMS, x.iso.sha256) that holds the image's sum.
    s=$(sha256sum -- "$1" | cut -d' ' -f1) || exit 1
    d=$(dir "$1")
    for c in "$d"/*CHECKSUM* "$d"/*SHA256SUMS* "$d"/*.sha256 "$d"/*.sha256sum; do
        [ -f "$c" ] && grep -qi -- "$s" "$c" && { printf 'ok %s\n' "$s"; exit 0; }
    done
    printf 'unknown %s\n' "$s" ;;
size) du -sh -- "$1" | cut -f1 ;;
phone)
    # The chosen device (Share zone), else the first one reachable.
    case "$arg" in *[!A-Za-z0-9_-]*) exit 2 ;; esac
    id=${arg:-$(kdeconnect-cli -a --id-only 2>/dev/null | head -n 1)}
    [ -n "$id" ] || exit 3
    for f; do kdeconnect-cli -d "$id" --share "$f" || exit 1; done ;;
print) if has lp; then lp -- "$@"; else lpr -- "$@"; fi ;;
mount) if has gnome-disk-image-mounter; then gnome-disk-image-mounter "$1"; else udisksctl loop-setup -r -f "$1"; fi ;;
thumb | page)
    # thumb: a tile's preview (N5, IslandShelfPreviews): a PDF's or an office document's first page, a video's frame, an
    # audio file's cover, 256 px on its long side, into the cache file the shell names. page: the quick look's page of a
    # PDF or office document, 1200 px wide, into "<cache>-<n>.png" (n read from the name); prints the file then the page
    # count. Both kept while newer than their file; written whole (a .part, then renamed) or not at all. An office
    # document is first turned into a PDF beside its previews ("<cache>.pdf", LibreOffice in its own profile).
    case "$arg" in /*.png) ;; *) exit 2 ;; esac
    if [ "$verb" = thumb ] && [ "$arg" -nt "$1" ]; then done_ "$arg"; exit 0; fi
    mkdir -p -- "$(dir "$arg")" || exit 1
    t="$arg.part"
    rm -f -- "$t" "$t.png"
    e=$(ext "$1" | tr 'A-Z' 'a-z')
    src=$1
    case "$e" in
    odt | ods | odp | doc | docx | xls | xlsx | ppt | pptx | rtf | epub)
        case "$verb" in thumb) p=${arg%.png}.pdf ;; *) p=${arg%-*}.pdf ;; esac
        if [ ! "$p" -nt "$1" ]; then office pdf "$1" "$p.part" && mv -f -- "$p.part" "$p"; fi
        [ -s "$p" ] || exit 1
        src=$p; e=pdf ;;
    esac
    if [ "$verb" = page ]; then
        [ "$e" = pdf ] || exit 2
        n=${arg##*-}; n=${n%.png}
        case "$n" in '' | *[!0-9]*) exit 2 ;; esac
        pages=$(pdfinfo "$src" 2>/dev/null | sed -n 's/^Pages: *//p')
        if [ ! "$arg" -nt "$1" ]; then
            timeout 20 pdftoppm -f "$n" -l "$n" -singlefile -png -scale-to-x 1200 -scale-to-y -1 "$src" "$t" && mv -f -- "$t.png" "$t"
            [ -s "$t" ] && mv -f -- "$t" "$arg" || exit 1
        fi
        done_ "$arg"; done_ "${pages:-1}"; exit 0
    fi
    case "$e" in
    pdf) timeout 15 pdftoppm -f 1 -l 1 -singlefile -png -scale-to 256 "$src" "$t" && mv -f -- "$t.png" "$t" ;;
    mp3 | flac | ogg | opus | wav | m4a | aac)
        # The picture attached to the sound, when it has one.
        timeout 15 ffmpeg -nostdin -loglevel error -i "$1" -an -frames:v 1 \
            -vf "scale=256:256:force_original_aspect_ratio=decrease" -c:v png -f image2 -y "$t" ;;
    *)
        # A clip shorter than a second has no frame at 1 s: its first one then.
        for s in 1 0; do
            [ -s "$t" ] || timeout 15 ffmpeg -nostdin -loglevel error -ss "$s" -i "$1" -frames:v 1 \
                -vf "scale=256:256:force_original_aspect_ratio=decrease" -c:v png -f image2 -y "$t"
        done ;;
    esac
    [ -s "$t" ] && mv -f -- "$t" "$arg" && done_ "$arg" ;;
list)
    # What an archive or a disc image holds, without extracting it: one path per line, 400 at most.
    case "$(base "$1" | tr 'A-Z' 'a-z')" in
    *.tar | *.tar.* | *.tgz | *.tbz2 | *.txz) timeout 20 tar -tf "$1" ;;
    *.zip) timeout 20 unzip -Z1 "$1" ;;
    *) timeout 20 7z l -ba -slt -- "$1" | sed -n 's/^Path = //p' ;;
    esac 2>/dev/null | head -n 400 ;;
info)
    # A picture: width height, then the shot's date, camera make and model from EXIF (blank lines when absent).
    timeout 15 identify -quiet -format '%w %h\n%[EXIF:DateTimeOriginal]\n%[EXIF:Make]\n%[EXIF:Model]\n' "$1[0]" 2>/dev/null ;;
tags)
    # A sound or a video: its first picture stream's size, its length in seconds and its tags, "key=value" lines.
    timeout 15 ffprobe -v error -select_streams v:0 -show_entries stream=width,height:format=duration:format_tags=title,artist,album,date,genre \
        -of default=noprint_wrappers=1 "$1" 2>/dev/null ;;
move)
    # The destination folder: an absolute path that exists, never empty (free would aim at the root).
    case "$arg" in /*) [ -d "$arg" ] || exit 2 ;; *) exit 2 ;; esac
    # Refused before anything moves: a read-only folder (7), a folder into itself or below it (6).
    [ -w "$arg" ] || exit 7
    for f; do case "$arg/" in "$f/"*) exit 6 ;; esac; done
    for f; do
        t=$(free "$arg" "$(stem "$f")" "$(ext "$f")")
        { mv -n -- "$f" "$t" && [ -e "$t" ] && printf '%s\t%s\n' "$f" "$t"; } || exit 1
    done ;;
copy)
    case "$arg" in /*) [ -d "$arg" ] || exit 2 ;; *) exit 2 ;; esac
    for f; do
        t=$(free "$arg" "$(stem "$f")" "$(ext "$f")")
        { cp -a -- "$f" "$t" && printf '%s\t%s\n' "$f" "$t"; } || exit 1
    done ;;
unmove)
    # A move taken back (or done again): pairs "from to", each moved under its old name, never over a file there now.
    [ $(($# % 2)) -eq 0 ] || exit 2
    while [ $# -gt 1 ]; do
        { [ -e "$2" ] || [ -L "$2" ]; } && exit 5
        { mv -n -T -- "$1" "$2" && [ -e "$2" ] && printf '%s\t%s\n' "$1" "$2"; } || exit 1
        shift 2
    done ;;
*) exit 2 ;;
esac
