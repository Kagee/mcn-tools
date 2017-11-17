#! /usr/bin/env python3
import re
import urllib.request

import telnetlib

def get_non_ascii():
    resource = urllib.request.urlopen("https://www.norid.no/en/regelverk/navnepolitikk/")
    content =  resource.read().decode(resource.headers.get_content_charset())
    result = re.search('<a id="link3">(.*)<a id="link4">', content, re.MULTILINE|re.DOTALL)
    chars = []
    for c in result.group(0):
        if (ord(c) > 0xBF): # because 'NO-BREAK SPACE' (U+00A0)
            chars.append(c)

    chars = sorted(set(chars))
    r = []
    for c in chars:
        r.append((c, "\\x{" + "{:0X}".format(ord(c)) + "}"))
    # list of pairs oc unicode char and \x-escape
    return r

def get_cat_domains(repl):
    whois = telnetlib.Telnet("whois.norid.no", 43)
    whois.write("-c utf-8 NNRI4O-NORID\n".encode('ascii'))
    result = whois.read_all()
    whois.close()
    s = result.decode('utf-8')
    #a_file = open('whois.txt', encoding='utf-8')
    #s = a_file.read()
    #print(s)
    r = re.search('^Domains\.*: (.*)', s, re.MULTILINE)
    #print("0: " + r.group(0))
    if r:
        domains = r.group(1).split()
        repl = get_non_ascii()
        for i in enumerate(domains):
            for (q,t) in repl:
                domains[i[0]] = domains[i[0]].replace(q,t)
        return domains

na = get_non_ascii()
for p in na:
    print (p[0], p[1])

print(get_cat_domains(na))
