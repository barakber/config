#!/usr/bin/env sh
# ranger supports enhanced previews.  If the option "use_preview_script"
# is set to True and this file exists, this script will be called and its
# output is displayed in ranger.  ANSI color codes are supported.

# NOTES: This script is considered a configuration file.  If you upgrade
# ranger, it will be left untouched. (You must update it yourself.)
# Also, ranger disables STDIN here, so interactive scripts won't work properly

# Meanings of exit codes:
# code | meaning    | action of ranger
# -----+------------+-------------------------------------------
# 0    | success    | success. display stdout as preview
# 1    | no preview | failure. display no preview at all
# 2    | plain text | display the plain content of the file
# 3    | fix width  | success. Don't reload when width changes
# 4    | fix height | success. Don't reload when height changes
# 5    | fix both   | success. Don't ever reload

# Meaningful aliases for arguments:
path="$1"    # Full path of the selected file
width="$2"   # Width of the preview pane (number of fitting characters)
height="$3"  # Height of the preview pane (number of fitting characters)

maxln=200    # Stop after $maxln lines.  Can be used like ls | head -n $maxln
max_file_size_to_read=3147528 # 3 Mb
file_size=$(stat --printf="%s" "$path")

# Find out something about the file:
mimetype=$(file --mime-type -Lb "$path")
extension=${path##*.}

# Functions:
# runs a command and saves its output into $output.  Useful if you need
# the return value AND want to use the output in a pipe
try() { output=$(eval '"$@"'); }

# writes the output of the previouosly used "try" command
dump() { echo "$output"; }

separator() { [ ! -z "$output" ] && echo "----------------------------------------------------------------------------------------"; }

# a common post-processing function used after most commands
trim() { head -n "$maxln"; }

# wraps highlight to treat exit code 141 (killed by SIGPIPE) as success
highlight() { command highlight "$@"; test $? = 0 -o $? = 141; }

try_hexdump()
{
    xxd -l 880 "$path" && exit 4 || exit 1
}

try_md5() 
{
    if [ "$file_size" -lt "$max_file_size_to_read" ]; then
        try md5sum "$path" && { echo -n "md5: "; dump | awk '{print $1}' | trim | fmt -s -w $width; separator; }
    fi
}

try_git()
{
    try git diff --shortstat "$path" && { dump | grep -q " 1 file" && dump | head -20 | trim | fmt -s -w $width; }
    try git log --color -n 1 -- "$path" && { dump | grep -q "commit" && dump | head -20 | trim | fmt -s -w $width; separator; }
}

try_elf_headers()
{
    try readelf -hd "$path" && { dump | grep "Class:\|Data:\|ABI:\|Type:\|Machine:\|(NEEDED)" | trim; separator; }
}
 
try_elf_rodata_strings()
{
    if [ "$file_size" -lt "$max_file_size_to_read" ]; then
        try readelf -x .rodata "$path" && { dump | sed '1,2d' | sed 's/^.\{12\}\(.\{36\}\).*$/\1/' | xxd -r -p | strings | trim ; separator; }
    else
        try_hexdump
    fi
}

try_java_decompile()
{
    tempfile=$(mktemp --suffix=.java)
    jad -p "$path" > "$tempfile" 
    try highlight --out-format=ansi "$tempfile" && { dump | trim; }
    rm "$tempfile"
    exit 5
}

#----------------------------------------------------------------------------------------
on_text()
{
        try_git
        # Syntax highlight for text files:
        try highlight --out-format=ansi "$path" && { dump | trim; exit 5; } || cat "$path"
        exit 0
}

on_docx()
{
    try docx2txt "$path" - && { dump | trim; exit 5;} || try_hexdump
}

on_archive()
{
        try als "$path" && { dump | trim; exit 0; }
        try acat "$path" && { dump | trim; exit 3; }
        try bsdtar -tf "$path" && { dump | trim; exit 0; }
        exit 1
}

on_rar()
{
        try unrar -p- lt "$path" && { dump | trim; exit 0; } || exit 1
}

on_html()
{
        try w3m    -dump "$path" && { dump | trim | fmt -s -w $width; exit 4; }
        try lynx   -dump "$path" && { dump | trim | fmt -s -w $width; exit 4; }
        try elinks -dump "$path" && { dump | trim | fmt -s -w $width; exit 4; }
}

on_media()
{
        # Display information about media files:
        exiftool "$path" && exit 5
        # Use sed to remove spaces so the output fits into the narrow window
        try mediainfo "$path" && { dump | trim | sed 's/  \+:/: /;';  exit 5; } || exit 1
}

on_iso()
{
    try isoinfo -d -i "$path" && { dump | trim; exit 0; } || try_hexdump
}

on_elf() 
{ 
        try_elf_headers
        try_elf_rodata_strings
        exit 5;
}

on_pe()
{
    try pev -cd "$path" && { dump | trim; separator; }
    try objdump -p "$path" && { dump | trim; separator; exit 5;} || exit 1
}

on_binary()
{
    try_hexdump
}

on_pdf()
{
        try pdftotext -l 10 -nopgbrk -q "$path" - && \
            { dump | trim | fmt -s -w $width; exit 0; } || exit 1
}

on_pcap()
{
        try tshark -c 55 -r "$path" && { dump | trim; exit 5; } || exit 1
}

on_class()
{
    try_java_decompile
}

on_torrent()
{
        try transmission-show "$path" && { dump | trim; exit 5; } || exit 1
}

on_image()
{
        # Ascii-previews of images:
        img2txt --gamma=0.6 --width="$width" "$path" && exit 4 || exit 1
}
#----------------------------------------------------------------------------------------

try_md5
case "$extension" in
    # Archive extensions:
    7z|a|ace|alz|arc|arj|bz|bz2|cab|cpio|deb|gz|jar|lha|lz|lzh|lzma|lzo|\
    rpm|rz|t7z|tar|tbz|tbz2|tgz|tlz|txz|tZ|tzo|war|xpi|xz|Z|zip)
        { on_archive; };;
    docx)
        { on_docx; };;
    rar)
        { on_rar; };;
    pdf) 
        { on_pdf; };;
    torrent) 
        { on_torrent; };;
    htm|html|xhtml)
        { on_text; };;
    elf|o|so|ko)
        { on_elf; };;
    dll|exe)
        { on_pe; };;
    iso)
        { on_iso; };;
    pcap)
        { on_pcap; };;
    class)
        { on_class; };;
    bin)
        { on_binary; };;
esac

case "$mimetype" in
    text/* | */xml)
        { on_text; };;
    video/* | audio/*) 
        { on_media; };;
    application/zip)
        { on_archive; };;
    application/x-gzip)
        { on_archive; };;
    application/pdf)
        { on_pdf; };;
    application/x-iso9660-image)
        { on_iso; };;
    application/x-executable|application/x-sharedlib)
        { on_elf; };;
    application/x-dosexec)
        { on_pe;  };;
    application/x-java-applet)
        { on_class; };;
    #image/*)
    #    { on_image; };;
    *)
        { on_binary; };;
esac

exit 1
