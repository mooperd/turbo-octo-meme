import http.client, ssl, json

conn = http.client.HTTPSConnection("nsx-rhr3clz438.ionoscloud.tools", context = ssl._create_unverified_context())
payload = ''
headers = {
  'Cookie': 'JSESSIONID=4BE9A393A041975F0F9DE497F766020D',
  'X-XSRF-TOKEN': 'a53b6545-46c4-4a65-af60-3d48e6d46ef2'
}


leases = conn.request("GET", "/api/v1/dhcp/servers/d901bba2-14a4-498d-af9e-92ce7551a905/leases?pool_id=014252c8-65d8-4335-b548-93b419963f6b", payload, headers)
res = conn.getresponse()
response_json = json.loads(res.read())

for lease in response_json["leases"]:
    print(lease)
    # 'mac_address': '00:50:56:86:ab:1a', 'ip_address': '10.141.10.169',
    conn.request("DELETE", "/api/v1/dhcp/servers/d901bba2-14a4-498d-af9e-92ce7551a905/leases?mac={}&ip={}".format(lease["mac_address"], lease["ip_address"]), payload, headers)
    res = conn.getresponse()
    data = res.read()
print(data.decode("utf-8"))
