#!/bin/bash

ANONFILES_USERAGENT="Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:95.0) Gecko/20100101 Firefox/95.0"
ANONFILES_PROXY="socks5h://localhost:9050"
ANONFILES_CURL_OPTS="--verbose"

ANONFILES_ENCODING="UTF-8"
CURL_ENCODING="CP1251"

COOKIE_FILE=$(mktemp)

PAGE_FILE=$(mktemp)
PAGE_STATUS=$(curl --proxy "$ANONFILES_PROXY" --url "$1"				\
	--cookie-jar "$COOKIE_FILE" --cookie "$COOKIE_FILE"				\
	--user-agent "$ANONFILES_USERAGENT" "$ANONFILES_CURL_OPTS"	 		\
	-k -H "Content-Type: text/html; charset=UTF-8" -X "GET" 			\
	--write-out "%{http_code}" --output "$PAGE_FILE" | head -c 3)
if [[ $PAGE_STATUS != 200 ]]; then
	rm -f "$PAGE_FILE"
	echo "HTTP $PAGE_STATUS: Failed request anonfiles download page" 1>&2
	exit 1
fi

CDN_FILE_LINK=$(mktemp)
CDN_FILE_URL=$(iconv -f "$ANONFILES_ENCODING" -t "$CURL_ENCODING" "$PAGE_FILE"		\
	| sed -r 's~(href="https://cdn)([^"]+).*~\n\1\2~g'				\
	| awk '/^(href)/,//'| sed -r 's~(href=")~~g')
echo "$CDN_FILE_URL" > "$CDN_FILE_LINK"

rm -rf "$PAGE_FILE"
if [[ -z "$CDN_FILE_URL" ]]; then
	echo "CDN file URL not found in anonfiles page" 1>&2
	exit 1
else
	echo "CDN download URL: $CDN_FILE_URL"
fi

FILE_STATUS=$(curl --proxy "$ANONFILES_PROXY"						\
	--url $(iconv -f "$CURL_ENCODING" -t "$ANONFILES_ENCODING" "$CDN_FILE_LINK")	\
	--cookie-jar "$COOKIE_FILE" --cookie "$COOKIE_FILE"				\
	--user-agent "$ANONFILES_USERAGENT" "$ANONFILES_CURL_OPTS"			\
	-k -X "GET" --write-out "%{http_code}" --remote-name-all --compressed)
if [[ $FILE_STATUS != 200 ]]; then
	echo "HTTP $FILE_STATUS: Failed to download file from CDN" 1>&2
	exit 1
fi

rm -f "$COOKIE_FILE"
