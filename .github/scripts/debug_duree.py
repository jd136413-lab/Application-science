import requests, re
UA={"User-Agent":"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36","Accept-Language":"en"}
t=requests.get("https://www.youtube.com/@NASASpaceflight/videos",headers=UA,cookies={"CONSENT":"YES+1"},timeout=15).text
i=t.find("fAGdYMJDqGk"); print(i); 
for m in re.finditer("fAGdYMJDqGk",t): print(m.start())
j=t.find("25:18"); print("2518",j); print(t[max(0,j-700):j+50].replace("\\n"," ") if j>0 else t[i:i+1500])
print("LENGTH keys", set(re.findall(r'"(\w*[Ll]ength\w*)"',t)))
