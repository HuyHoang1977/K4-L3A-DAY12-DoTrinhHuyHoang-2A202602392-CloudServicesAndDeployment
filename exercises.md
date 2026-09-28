# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: ..........................  Mã học viên: ..........................

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> Tình huống cụ thể của tôi: tôi deploy service lên Render, đặt
> `AGENT_API_KEY` trên dashboard xong, build và thấy dòng
> `==> Your service is live`. Tôi tưởng xong, đóng laptop đi. Đó là lúc mọi
> thứ đều đúng — còn khi chưa deploy thì rất dễ quên.
>
> Nhưng nếu tôi đặt mặc định `"changeme"` thì chuyện gì xảy ra: tôi deploy
> thành công, tôi test bằng máy mình thấy hết OK vì mình cũng gửi
> `changeme` đi. Rồi Lab Coach mở `DEPLOYMENT.md` của tôi, gọi thử public URL
> mà không cần key — và **anh ấy gọi được**. Không phải vì anh ấy giỏi, mà vì
> tôi đã để sẵn cửa. Học sinh khác cũng gọi được, và tôi trả tiền cho họ
> (dù lab này dùng mock LLM nên chưa tốn đồng nào — nhưng bài học thì có thật:
> hóa đơn LLM thật sẽ do người lạ quyết định).
>
> Fail fast đổi thứ tự phát hiện lỗi: với `"changeme"` thì lỗi lộ ra lúc có
> người lạ dùng, còn với bắt buộc thì lỗi lộ ra lúc deploy — sớm hơn, và
> đúng lúc mình còn ở ngay trước màn hình. Cái đắt nhất không phải lúc app
> chết, mà là lúc app sống nhưng sai mà không ai biết.
>
> Tôi cũng gặp đúng cơ chế này khi deploy: Render inject `PORT` và
> `REDIS_URL` tự động, nên nếu tôi cố tự set thì dễ set sai. Cùng một nguyên
> tắc — để platform quyết định những thứ nó biết, code chỉ đọc.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> Đây là dòng log thật tôi thu được khi gọi `/ask` qua nginx với 3 replica:
>
> ```json
> {"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T08:44:21.561088+00:00", "user_id": "lb-8aeb60", "cost_usd": 2.415e-05, "tokens_in": 1, "tokens_out": 40}
> ```
>
> **Việc 1 — Tính tiền.** Trường `cost_usd` là số, nên tôi lấy riêng nó ra
> cộng dồn bằng `jq`: `docker logs agent | jq -r 'select(.event=="ask_completed") | .cost_usd' | paste -sd+ | bc`.
> Con số đó trả lời trực tiếp câu hỏi "tháng này tôi đã tốn bao nhiêu", đúng
> thứ cost guard của CP3 cần. Dòng `print("đã trả lời xong")` không có số
> trong đó nên không cộng được — muốn biết chi phí thì phải tự đoán nhân với
> token, mà đoán thì sai ngay.
>
> **Việc 2 — Tìm lỗi theo user.** `grep '"user_id": "lb-8aeb60"'` ra đúng
> toàn bộ lượt của một người dùng, `jq 'select(.level=="error")'` ra những
> dòng lỗi. Khi có người báo "tôi hỏi mà không nhớ đại", tôi tra đúng họ ra
> trong vài giây. Với log dạng câu tự nhiên thì tôi phải đọc lại từ đầu đến
> cuối file log để tìm dòng liên quan — mà file log trên cloud xoay vòng và
> tôi không có gì để lọc.
>
> Thêm một điều nữa tôi thấy rõ khi làm bài này: `timestamp` ở định dạng
> ISO-8601 kèm múi giờ UTC cho phép ghép log của 3 container theo đúng thứ
> tự thời gian. Log dạng chữ có dấu chấm thì không. Tôi đã dùng đúng cách
> đó để chứng minh nginx chia đều 5/5/5 request ra 3 container.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 271 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> Chênh lệch 1.459 GB. Tôi đo thêm base image để biết phần nào đến từ đâu:
>
> ```
> python:3.11        1.61 GB
> python:3.11-slim    189 MB      (chênh 1.42 GB)
> ```
>
> Vậy **1.42 GB trong 1.459 GB là từ base image**. `python:3.11` bản đầy đủ
> cài sẵn rất nhiều thứ để build C extension (gcc, make, header hệ thống, thư
> viện phát triển của ImageMagick, apr, audit...). Không cái nào trong số đó
> cần thiết để chạy web service của tôi.
>
> Phần còn lại ~39 MB là `pip install` chạy trong image: tôi kiểm tra bằng
> cách vào trong container và `which gcc` —
>
> ```
> agent:single  → /usr/bin/gcc        (có compiler)
> agent:multi   → KHONG co gcc
> agent:single  → /root/.cache = 17 MB
> agent:multi   → khong co pip cache
> ```
>
> Nên còn 2 thứ nữa: **compiler** và **pip cache**. Cache thì tôi đã chặn
> bằng `PIP_NO_CACHE_DIR=1`; compiler thì chặn bằng cách không đưa nó sang
> stage cuối.
>
> Điều này cũng giải thích vì sao multi-stage vẫn đáng làm dù mọi thư viện
> của tôi đều có sẵn wheel (tức là về lý thuyết không cần biên dịch gì):
> ranh giới stage là **bảo đảm** image không bao giờ dính compiler, kể cả khi
> sau này tôi thêm một dependency bắt buộc phải build từ source. Tôi không
> phải nhớ để dọn — cấu trúc tự dọn.
>
> 271 MB còn lại = 189 MB interpreter + ~82 MB thư viện Python. Con số này
> cũng quyết định tốc độ deploy: Render build từ đầu mỗi lần, image nhỏ hơn
> thì push nhanh hơn.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> Tôi thêm đúng một dòng comment vào cuối `app/main.py` rồi build lại. Kết
> quả:
>
> ```
> #6  [runtime 2/6] WORKDIR /app                              CACHED
> #7  [builder 2/4] WORKDIR /build                            CACHED
> #8  [builder 3/4] COPY requirements.txt .                   CACHED
> #9  [builder 4/4] RUN pip install --prefix=/install ...    CACHED   ← quan trọng nhất
> #10 [runtime 3/6] COPY --from=builder /install /usr/local   CACHED
> #11 [runtime 4/6] COPY app ./app                            chạy lại
> #12 [runtime 5/6] COPY utils ./utils                        chạy lại
> #13 [runtime 6/6] RUN useradd ... && chown ...              chạy lại
> ```
>
> Bước tốn thời gian nhất — cài 27 thư viện — vẫn `CACHED`. Build lại mất
> chưa tới 3 giây thay vì gần 2 phút. Toàn bộ dependency đã cài vào
> `/install` được giữ nguyên, chỉ phần code phía sau phải copy lại.
>
> Điều tôi không đoán trước được và phải kiểm tra mới biết: `COPY utils`
> cũng chạy lại dù tôi **không** sửa `utils`. Lý do là cache key của mỗi
> bước phụ thuộc kết quả của bước trước nó. Bước `#11` đổi → `#12` mất cache
> → `#13` mất cache. Nó vẫn nhanh vì `COPY` chỉ mất chưa tới 1 giây, nhưng
> đây là lý do câu trả lời đúng không phải "chỉ layer code chạy lại" mà là
> "mọi thứ **từ** layer code trở đi chạy lại — nên phải đặt phần đắt nhất
> lên trước".
>
> Nếu đặt `COPY . .` lên trước `RUN pip install` như bản Dockerfile đầu:
> sửa một dấu phẩy trong code là `COPY . .` đổi hash → `pip install` mất
> cache → **cài lại toàn bộ 27 thư viện từ đầu mỗi lần sửa một dòng**. Với
> tôi mỗi lần deploy đã mất 3–6 phút chỉ để Render build, thêm 2 phút cài
> lại thư viện là thêm 30% thời gian chỉ vì một dòng code.
>
> Nói cách khác, thứ tự lệnh trong Dockerfile không phải sở thích về người
> đọc mà là quyết định chi phí thời gian của mỗi lần deploy.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> Chuỗi sự kiện, từng bước:
>
> 1. Kẻ tấn công gửi payload vào `/ask`. Giả sử tôi vô tình viết
>    `eval(user_input)` hoặc dùng `pickle.loads` trên dữ liệu người dùng nhập.
>    Payload được thực thi **bên trong** container.
> 2. Bên trong container, code của tôi chạy với UID 0. Nên payload chạy với
>    UID 0: đọc/ghi mọi file trong container, cài thêm package, mở socket ra
>    ngoài.
> 3. Container không phải máy ảo — nó dùng chung kernel với host. Các quyền
>    của nó là quyền thật trên kernel đó. Nếu host chạy root (mặc định của
>    rất nhiều máy chạy Docker), thì UID 0 trong container **là** UID 0 trên
>    host.
> 4. Từ đó kẻ tấn công ghi được vào `/var/lib/docker/`, đọc được image
>    của các container khác, thậm chí mount được filesystem của host vào một
>    container mới do chính họ điều khiển.
>
> `USER appuser` cắt ở **bước 2→3**: process bên trong container chạy với
> UID 10001 nên payload chỉ có được quyền của UID 10001, và UID 10001 đó là
> user không có đặc quyền trong container. Bước 3 không còn đường đi nữa.
>
> Tôi chọn cố định `--uid 10001` chứ không để Render/Docker cấp phát, để
> quyền trên volume không đổi mỗi lần build. Tôi cũng thêm
> `chown -R appuser:appuser /app` và `PYTHONDONTWRITEBYTECODE=1` — biến thứ
> hai để app không cần quyền ghi xuống đĩa, vì user thường không có quyền
> đó. Kiểm chứng:
>
> ```
> $ docker run --rm --entrypoint sh day12-agent:prod -c "id -u; id -un"
> 10001
> appuser
> ```

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

> **20 request.**
>
> Cách đạt: gửi 10 request vào khoảng giây 59 (ví dụ 10:00:59.00 →
> 10:00:59.90), chờ 100 mili-giây cho sang giây 00, rồi gửi tiếp 10 request
> ngay trong 10:01:00.00 → 10:01:00.90. Tổng cộng **20 request trong chưa tới
> 2 giây**, mà mỗi phút vẫn chỉ dùng đúng 10 — đúng hạn mức trên giấy tờ.
>
> Nguyên nhân là cửa sổ đóng cứng ở mốc phút: hai phút liên tiếp là hai
> bộ đếm độc lập, và khoảng thời gian 2 giây nằm trải trên **hai** bộ đếm,
> nên không bộ nào thấy hết 20.
>
> Sliding window của tôi không có lỗ hổng này vì tôi lưu timestamp của **từng
> request** vào Redis ZSET, rồi đếm `zcard` sau khi cắt bằng
> `zremrangebyscore(key, 0, now - 60)`. Mốc cắt luôn trượt theo thời điểm hiện
> tại chứ không neo vào mốc phút nào cả. Cùng kịch bản đó thì 10 request ở
> giây 59 trượt ra ngoài cửa sổ và chỉ 10 request còn lại được tính.
>
> Tôi có một chi tiết phải làm đúng khi viết phần này: member của ZSET phải
> là **chuỗi duy nhất** (`f"{now}:{uuid4().hex}"`), không phải timestamp thuần.
> Nếu để timestamp làm member thì hai request trong cùng một mili-giây sẽ ghi
> đè nhau, ta đếm thiếu, và kẻ spam vẫn vượt hạn mức được. Tôi có probe riêng
> cho việc này: 5 request cùng timestamp phải ra `hit_count == 5`.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

> Khác nhau về **thứ đo**: rate limit đo số **lượng** request trong 60 giây, cost
> guard đo **số tiền** đã tiêu trong tháng. Rate limit không nhìn câu hỏi dài
> bao nhiêu, cost guard không nhìn bạn gọi bao nhiêu lần. Chúng cũng khác nhau
> ở chỗ rate limit là **đếm rồi xoá** (cửa sổ trượt) còn cost guard là **cộng
> dồn** (`INCRBYFLOAT` vào key có tháng trong tên).
>
> **Rate limit cho qua, cost guard chặn:** tôi giới hạn `RATE_LIMIT_PER_MINUTE=10`
> nhưng tháng này tôi đã tiêu gần hết `MONTHLY_BUDGET_USD`. Gọi `/ask` lần
> thứ 3 trong phút thì rate limiter thấy 3 < 10 nên cho qua, nhưng
> `spent() + estimated_cost > budget` nên cost guard ném 402. Tôi kiểm chứng
> đúng tình huống này bằng cách nạp thẳng giá trị 999 vào key `cost:` trong
> Redis rồi gọi `/ask` → nhận `402 Payment Required`.
>
> **Cost guard cho qua, rate limit chặn:** ngược lại, tháng mới nên `spent()=0`
> và ngân sách còn nguyên, nhưng tôi đã gọi 10 lần trong một phút. Cost guard
> thấy còn nhiều tiền nên im lặng, rate limiter thấy đã đủ 10 nên trả
> `429 Too Many Requests`. Tôi gọi 13 lần liên tiếp lên service đã deploy
> và nhận đúng `200 200 200 200 200 200 200 200 200 429 429 429 429`.
>
> Cả hai đều phải chạy **trước** khi gọi LLM. Đó là điểm tôi nhấn mạnh nhất
> khi viết `/ask`: tiền mất ở bước gọi LLM, nên chặn sau là vừa mất tiền vừa
> trả lỗi. Thứ tự tôi dùng là rate limit (rẻ nhất) → cost guard → đọc lịch
> sử → mới gọi LLM.
>
> Còn một chi tiết dễ sai: `guard.record()` phải đặt **sau** khi đã sinh câu
> trả lời, không phải trước. Đặt trước thì những request sau bị chặn 402 cũng
> bị tính tiền dù không tốn đồng nào — cost guard tự tốn tiền của chính nó.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> Giả sử tôi gộp: `/health` cũng gọi `store.ping()`. Redis chết trong 30 giây
> thì chuỗi sự kiện là:
>
> 1. **Giây 0** — kết nối tới Redis hỏng. `/health` bắt đầu trả 503.
> 2. **Giây 0–5** — cả 3 container cùng trả 503, vì cả 3 đều dùng chung một
>    Redis nên chết đồng loạt.
> 3. **Giây 5–10** — orchestrator (Render/Docker/K8s) đọc `/health` thấy 503
>    và coi instance **đã chết** → **restart cả 3 container**.
> 4. **Giây 10–20** — 3 container cùng khởi động lại, cùng đòi Redis. Redis
>    vẫn chết nên app không startup được (lifespan fail) → container crash →
>    bị restart lại. Lặp lại.
> 5. **Giây 30** — Redis sống lại. Nhưng 3 container đang ở giữa vòng lặp
>    restart, và trong lúc đó **không còn instance nào phục vụ được**. Người
>    dùng gọi vào nhận 502.
>
> Kết cục: một sự cố nhỏ ở tầng Redis biến thành sự cố toàn hệ thống, và
> hệ thống còn tệ hơn trước vì **tự giết mình đúng lúc đang yếu nhất**.
>
> Đó là lý do hai endpoint phải tách bạch:
>
> | | `/health` (liveness) | `/ready` (readiness) |
> |---|---|---|
> | Câu hỏi | Process còn sống không? | Nhận traffic được chưa? |
> | Kiểm tra dependency | Không | Có |
> | Trả 503 thì sao | Orchestrator **restart** | Load balancer **ngừng gửi**, không restart |
>
> `/health` chỉ đọc biến `lifecycle.shutting_down` trong RAM — nhẹ, không
> chạm gì ra ngoài. Redis chết thì nó vẫn 200, nên không container nào bị
> restart vô lý. `/ready` thì `ping()` và trả 503, nhưng 503 ở đây chỉ có
> nghĩa là "đừng gửi traffic vào tôi lúc này", tuyệt đối không phải "giết tôi
> đi".
>
> Tôi đã kiểm chứng bằng cách `docker compose stop redis` rồi gọi thử:
> `/ready` → **503**, `/health` → **200**, và sau khi bật lại Redis thì
> `/ready` → **200** trở lại. Cả cụm container vẫn sống nguyên suốt.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

> Tôi chạy 3 replica sau nginx rồi gọi `/ask` 9 lần cùng một `X-User-Id`:
>
> ```
> history_length = 0, 2, 4, 6, 8, 10, 12, 14, 16
> ```
>
> Tăng đều 2 mỗi lượt, không có lần nào quay về 0 — dù mỗi request rơi vào
> một container khác nhau. Tôi đếm được cụ thể bằng `docker logs <id>` cho
> từng container: **5 / 5 / 5 request**, round-robin đều.
>
> Nếu lịch sử nằm trong một dict Python trong RAM mỗi container, con số sẽ
> **nhảy về 0 một cách ngẫu nhiên**: câu 1 có thể rơi vào container A, câu 2
> rơi vào B (thấy 0 lượt trước), câu 3 lại rơi vào A (thấy 2). Người dùng
> thấy agent "quên" vừa hỏi xong, và **không hiểu vì sao** vì mỗi câu hỏi
> riêng lẻ đều thành công.
>
> Tệ hơn nữa: container restart là mất sạch, kể cả khi chỉ có **một** replica.
> Deploy bản mới là mất trí nhớ.
>
> Cái làm tôi ấn tượng nhất khi đọc lại là bài test này dùng hai instance
> store khác nhau trên cùng một Redis:
>
> ```python
> container_a = ConversationStore(redis)
> container_b = ConversationStore(redis)
> container_a.append("u1", "user", "câu hỏi gửi vào container A")
> history = container_b.get_history("u1")   # phải thấy 1
> ```
>
> Hai object Python khác nhau, hai "process" khác nhau, nhưng thấy cùng dữ
> liệu — vì state nằm ở Redis chứ không nằm trong object. Đó mới đúng nghĩa
> stateless, chứ không chỉ là "không lưu gì vào biến toàn cục".
>
> (Ghi chú thực tế: tôi phải tách nginx ra file `docker-compose.lb.yml` riêng
> và dùng `ports: !reset []` cho agent, vì bản compose publish cổng 8000 ra
> host nên scale 3 sẽ lỗi `Bind for 0.0.0.0:8000 failed`. Nhiều replica không
> thể cùng tranh một cổng host.)

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> Lỗi của tôi: **`REDIS_URL` sai hostname.**
>
> **Triệu chứng:** service lên được, `/health` trả `200`, `/ask` trả đúng
> 401 không key — nhưng `/ready` trả **503** với `{"status":"not ready","redis":false}`.
> Build không lỗi, app không crash, nên nhìn từ phía deploy thì thành công.
>
> **Nguyên nhân:** tôi copy nguyên dòng `REDIS_URL=redis://localhost:6379/0`
> từ `.env` ở máy rồi dán lên Render. Nhưng `localhost` **bên trong
> container Render** là chính container web service đó, không phải Redis —
> và ở đó không có Redis nào để kết nối. Cùng kiểu lỗi với `redis://redis:6379`
> (tên service trong compose) cũng vô dụng trên Render, vì Render đặt tên
> instance dạng `red-xxxx`.
>
> **Cách tìm ra:** tôi cố tách hai nghi vấn ra. Đầu tiên tôi gọi `/health` →
> 200, chứng minh app đã boot và `PORT` đúng (Render gán cổng, Dockerfile đọc
> `${PORT:-8000}`). Rồi tôi so `/ready` với `/ask`: auth chạy đúng, chỉ có
> Redis là hỏng. Khả năng còn lại gần như chỉ có một: cấu hình connection.
> Để chắc chắn, tôi dựng lại đúng tình huống ở local — chạy container với
> `REDIS_URL` trỏ tới host không có thật — và thấy `/ready` trả đúng 503
> `redis:false` y hệt, còn `/health` vẫn 200. Lúc đó biết chắc là lỗi
> connection chứ không phải lỗi logic.
>
> **Cách sửa:** vào **Key Value** trên Render → menu **Connect** → copy
> **Internal URL** (dạng `redis://red-xxxx:6379`), dán vào Environment của
> web service rồi Save & Deploy. Internal URL đi qua private network nên
> nhanh hơn, và không cần mật khẩu.
>
> **Bài họt tôi rút ra, và cũng là lý do `/ready` phải tồn tại:** nếu chỉ có
> `/health` thì tôi sẽ kết luận "deploy thành công" và nộp bài với một
> service mà mọi câu hỏi `/ask` đều 500. `/ready` là thứ **chứng minh** app
> thật sự dùng được chứ không chỉ còn sống. Cũng như trong `docker-compose.yml`
> tôi ghi: `localhost` bên trong container là chính container đó — lỗi này
> mình không tự nghĩ ra được nếu chưa từng đụng.
>
> (Lỗi thứ hai tôi gặp lúc chạy `--scale agent=3`:
> `Bind for 0.0.0.0:8000 failed: port is already allocated` — mỗi replica
> đều muốn chiếm cùng cổng host 8000.)
