import requests, re, json
u="https://www.youtube.com/watch?v=7JDRHVi0YYI"
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36","Accept-Language":"en"}
for h in [{"User-Agent":"NovaSTEM/1.0"},UA]:
    r=requests.get(u,headers=h,cookies={"CONSENT":"YES+1"},timeout=15)
    print(r.status_code,r.url[:80],len(r.text),'lengthSeconds' in r.text, re.search(r'"lengthSeconds":"(\d+)"',r.text), 'consent' in r.url)
for client in [{"clientName":"WEB","clientVersion":"2.20241101.00.00"},{"clientName":"ANDROID","clientVersion":"19.44.38","androidSdkVersion":30}]:
    try:
        r=requests.post("https://www.youtube.com/youtubei/v1/player",json={"videoId":"7JDRHVi0YYI","context":{"client":client}},headers=UA,timeout=15)
        j=r.json(); print(client["clientName"],r.status_code,j.get("videoDetails",{}).get("lengthSeconds"),j.get("playabilityStatus",{}).get("status"))
    except Exception as e: print(client["clientName"],e)
r=requests.get("https://www.youtube.com/shorts/7JDRHVi0YYI",headers=UA,allow_redirects=False,timeout=15); print("shorts",r.status_code)
