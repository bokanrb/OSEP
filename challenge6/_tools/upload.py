#!/usr/bin/env python3
"""Upload a file via the Final/ ASP.NET WebForms upload at 192.168.114.181.

Usage:
    python3 upload.py <localpath> [filename] [content-type]
"""
import sys, re, requests

URL = 'http://192.168.114.181/Final/'

fpath = sys.argv[1] if len(sys.argv) > 1 else None
if not fpath:
    print('usage: upload.py <localpath> [filename] [content-type]')
    sys.exit(1)
fname = sys.argv[2] if len(sys.argv) > 2 else fpath.rsplit('/', 1)[-1]
ctype = sys.argv[3] if len(sys.argv) > 3 else 'application/octet-stream'

s = requests.Session()
r = s.get(URL)
h = r.text

def grab(n):
    m = re.search(r'name="' + n + r'"[^>]*value="([^"]+)"', h)
    if not m:
        raise RuntimeError(f'could not find {n} in form')
    return m.group(1)

data = {
    '__VIEWSTATE': grab('__VIEWSTATE'),
    '__VIEWSTATEGENERATOR': grab('__VIEWSTATEGENERATOR'),
    '__EVENTVALIDATION': grab('__EVENTVALIDATION'),
    '__EVENTTARGET': '',
    '__EVENTARGUMENT': '',
    'ctl00$MainContent$UploadButton': 'Upload',
}
files = {'ctl00$MainContent$FileUploadControl': (fname, open(fpath, 'rb'), ctype)}

r2 = s.post(URL, data=data, files=files)

m = re.search(r'StatusLabel">([^<]*)</span>', r2.text)
print('STATUS:', m.group(1) if m else '(no StatusLabel)')
print('HTTP :', r2.status_code, 'len=', len(r2.text))
