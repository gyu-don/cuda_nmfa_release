import json
import sys

try:
    jsonname = sys.argv[1]
except IndexError:
    print("Usage: %s jsonfile" % sys.argv[0])
    exit()
with open(jsonname) as f:
    data = json.load(f)
# Assume that data is 2d-array [[float, ...], ...]
# Extracted format:
# width height
# num
# num
# ...
print(len(data[0]), len(data))
for line in data:
    for num in line:
        print(num)
