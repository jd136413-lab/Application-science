import requests, re
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36","Accept-Language":"en"}
for vid in ["7JDRHVi0YYI","fAGdYMJDqGk","gTpn5Whu2ao"]:
    r=requests.get("https://www.youtube.com/watch?v="+vid,headers=UA,cookies={"CONSENT":"YES+1"},timeout=15)
    t=r.text
    print(vid, re.search(r'itemprop="duration" content="([^"]+)"',t), re.search(r'approxDurationMs\\?":\\?"(\d+)',t), re.search(r'"lengthText":\{[^}]{0,200}',t) and re.search(r'"lengthText":\{[^}]{0,200}',t).group(0)[:120], re.search(r'"simpleText":"(\d+:\d\d(?::\d\d)?)"',t))
    s=requests.get("https://www.youtube.com/shorts/"+vid,headers=UA,allow_redirects=False,timeout=15); print("  shorts",s.status_code,s.headers.get("location"))
