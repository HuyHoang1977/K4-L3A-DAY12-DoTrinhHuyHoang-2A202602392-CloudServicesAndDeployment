# Thông Tin Deploy — Checkpoint 5

> `pytest tests/test_cp5.py` đọc file này để tìm địa chỉ service và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Đỗ Trình Huy Hoàng |
| Mã học viên | 2A202602392 |
| Repo | https://github.com/HuyHoang1977/K4-L3A-DAY12-DoTrinhHuyHoang-2A202602392-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://k4-l3a-dotrinhhuyhoang-2a202602392-cloud.onrender.com |
| Platform | Render (Hobby, plan `free`, region Oregon) |
| Ngày deploy | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Nguồn / Ghi chú |
|------|--------|-----------------|
| `PORT` | ✅ | Render tự gán, không khai báo trong `render.yaml` |
| `AGENT_API_KEY` | ✅ | Nhập tay ở dashboard Render, khai báo `sync: false` trong `render.yaml` — không nằm trong repo |
| `REDIS_URL` | ✅ | Internal URL của Key Value `day12-redis`, lấy qua `fromService` / dán tay: hostname dạng `red-xxxx` |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Cấu Hình Đã Dùng

`render.yaml` khai báo 2 resource:

- `day12-agent` — web service, `runtime: docker`, đọc `./Dockerfile`,
  `healthCheckPath: /health`, `maxShutdownDelaySeconds: 60`
- `day12-redis` — Key Value (Valkey 8) plan `free`, `maxmemoryPolicy: noeviction`,
  `ipAllowList: []` nghĩa là chỉ nhận kết nối qua private network nội bộ Render

Hai service cùng region `oregon` — bắt buộc, vì Render chỉ nối được private
network giữa các service cùng region.

Ba điều chỉnh so với bản `render.yaml` cho sẵn của lab:

1. `type: redis` → `type: keyvalue` (`redis` chỉ là alias đã deprecated)
2. Khai báo rõ `ipAllowList` — đây là trường **bắt buộc** với Key Value
3. `maxmemoryPolicy: noeviction` thay cho mặc định `allkeys-lru`, để khi Redis
   đầy thì báo lỗi thay vì xóa âm thầm dữ liệu

## Lệnh Kiểm Tra

```bash
URL=https://k4-l3a-dotrinhhuyhoang-2a202602392-cloud.onrender.com

# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i $URL/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i $URL/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST $URL/ask -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST $URL/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST $URL/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Ngày 2026-09-28, chạy từ máy cá nhân sau khi deploy:

**Lệnh 1 — `/health`**
```
HTTP/1.1 200 OK
content-type: application/json
{"status":"ok","service":"day12-agent","version":"1.0.0"}
```

**Lệnh 2 — `/ready`** (bằng chứng Redis đã nối được)
```
HTTP/1.1 200 OK
{"status":"ready","redis":true}
```

**Lệnh 3 — `/ask` không có API key**
```
HTTP/1.1 401 Unauthorized
{"detail":"invalid or missing API key"}
```

**Lệnh 4 — `/ask` có API key**
```
HTTP/1.1 200 OK
{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa
môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.",
 "user_id":"sv-test","history_length":0,"cost_usd":2.145e-05,
 "tokens":{"in":3,"out":35}}
```

**Lệnh 5 — rate limit**
```
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
200: 9   429: 6
```
Chỉ 9 request đầu trả 200 chứ không phải 10, vì lệnh 4 vừa dùng 1 lượt của
user `sv-test` nên cửa sổ trượt 60 giây đã có sẵn 1 request. 6 lượt sau bị
chặn đúng hạn mức `RATE_LIMIT_PER_MINUTE=10`.

**Kiểm tra bổ sung — stateless trên cloud**
```
luot 1 -> history_length = 0
luot 2 -> history_length = 2
luot 3 -> history_length = 4
luot 4 -> history_length = 6
```
Lịch sử tăng đều qua từng lượt gọi, chứng minh state nằm trong Redis chứ
không phải RAM của container.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trang quản lý service trên Render
- `screenshots/redis.png` — trang Key Value `day12-redis`, tab Connect
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl

## Lưu Ý Về Free Tier

Render plan `free` có hai hạn chế đã biết trước:

- **Service ngủ sau 15 phút không có traffic.** Cold start mất 30–60 giây.
  Bộ test CP5 đã có `FIRST_CALL_TIMEOUT = 60.0` cho lệnh đầu tiên, nhưng
  nếu chạy `pytest` thì nên gọi `/health` trước để đánh thức container,
  tránh lệnh đầu tiên rơi vào `/ready` và bị timeout.
- **Key Value plan `free` chỉ 25 MB RAM, không có persistence.** Mỗi lần
  instance restart là mất sạch dữ liệu. Không ảnh hưởng chấm điểm vì
  service vốn stateless — chỉ mất lịch sử hội thoại và bộ đếm rate limit.
