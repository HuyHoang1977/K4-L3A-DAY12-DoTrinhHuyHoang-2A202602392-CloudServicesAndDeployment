# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
# Cấu trúc: 2 stage.
#   builder — cài dependency vào /install, rồi BỊ VỨT đi
#   runtime — chỉ nhận lại kết quả cài đặt + code, không có compiler
#
# Vì sao tách stage? Stage builder là nơi ta có thể để mọi thứ linh
# hoạt (gcc, header hệ thống, build cache) vì nó không bao giờ thành
# image chạy thật. Kết quả là stage runtime chỉ còn interpreter +
# thư viện + code. Ở lab này mọi thư viện đều có sẵn wheel nên
# builder không cần cài build-essential — nhưng ranh giới stage vẫn
# được giữ để image không bao giờ dính compiler, kể cả khi sau này
# thêm một dependency nào đó bắt buộc phải biên dịch.
#
# Build:  docker build -t day12-agent:prod .
# Chạy:   docker run -e AGENT_API_KEY=... -p 8000:8000 day12-agent:prod
# Kiểm tra: pytest tests/test_cp2.py -v
# ═══════════════════════════════════════════════════════════════════


# ───────────────────────────────────────────────────────────────────
# Stage 1 — builder: chỉ lo phần "cài đặt"
# ───────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS builder

ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /build

# requirements.txt COPY RIÊNG một lệnh, và đứng TRƯỚC khi copy code.
# Docker cache từng layer và chỉ huỷ cache từ layer đầu tiên thay đổi
# trở đi → sửa 1 dòng trong app/ thì không phải cài lại thư viện.
COPY requirements.txt .

# --prefix=/install: cài vào một thư mục tạm, để stage sau copy nguyên
# khối sang. Không cài thẳng vào hệ thống của builder rồi copy cả
# site-packages — cách đó dễ lẫn file của chính base image.
RUN pip install --prefix=/install -r requirements.txt


# ───────────────────────────────────────────────────────────────────
# Stage 2 — runtime: đây mới là image thật
# ───────────────────────────────────────────────────────────────────
FROM python:3.11-slim AS runtime

# PYTHONDONTWRITEBYTECODE: không ghi .pyc xuống đĩa (image nhỏ hơn, và
#   user thường không cần quyền ghi vào /app).
# PYTHONUNBUFFERED: log của uvicorn phải ra được stdout thay vì bị giữ
#   trong buffer — nếu không, `docker logs` sẽ trống khi app crash.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Chỉ copy KẾT QUẢ từ builder — không có gcc, không có header, không
# có pip cache. Đây là chỗ quyết định dung lượng image.
COPY --from=builder /install /usr/local

# Code copy SAU pip install (xem giải thích ở stage builder).
# Copy từng thư mụng thay vì `COPY . .` để .dockerignore là lớp lọc
# cuối cùng, không phải lớp lọc duy nhất.
COPY app ./app
COPY utils ./utils

# Container chạy bằng user thường. Nếu container chạy root thì một lỗ
# hổng bất kỳ trong app cũng đòi được quyền root trên host. uid cố
# định 10001 để quyền trên volume bind không bị đổi mỗi lần build.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

# EXPOSE chỉ là tài liệu, không mở cổng thật — cổng thật do -p quyết
# định. Giữ ở đây để nhớ app nghe ở cổng nào khi không có PORT.
EXPOSE 8000

# Docker chỉ biết container còn phục vụ được khi có HEALTHCHECK. Không
# có nó thì `docker compose up` không biết lúc nào agent đã sẵn sàng,
# và orchestrator không loại được instance đang chết khỏi vòng xoay.
# Gọi /health (liveness — không chạm Redis) chứ không gọi /ready: nếu
# Redis chập chờn, cả cụm container bị đánh dấu unhealthy rồi restart
# theo — lúc đó không còn ai phục vụ nữa.
# Cổng đọc từ $PORT vì cloud tự gán cổng.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % os.environ.get('PORT','8000'), timeout=4)" || exit 1

# `exec` để uvicorn thành PID 1 và nhận trực tiếp SIGTERM từ Docker.
# Nếu bọc bằng `sh -c` mà không exec, tín hiệu dừng không tới được app
# → container bị SIGKILL sau timeout → request đang xử lý bị rớt.
# `${PORT:-8000}` vì Railway/Render/Cloud Run tự set biến PORT.
# 0.0.0.0 chứ không phải 127.0.0.1: bind localhost thì ngoài container
# không gọi vào được.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
