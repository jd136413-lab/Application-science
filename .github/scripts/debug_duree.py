import requests, re
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36","Accept-Language":"en"}
for nom in ["NASASpaceflight","EverydayAstronaut","Samsung"]:
    t=requests.get(f"https://www.youtube.com/@{nom}/videos",headers=UA,cookies={"CONSENT":"YES+1"},timeout=15).text
    res=re.findall(r'"videoId":"([\w-]{11})".{0,3000}?"lengthText":\{"accessibility":\{"accessibilityData":\{"label":"[^"]*"\}\},"simpleText":"([\d:]+)"',t)
    print(nom,len(t),len(res),res[:8])
