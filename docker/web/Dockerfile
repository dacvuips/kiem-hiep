# Image Nginx Alpine siêu nhẹ (~20MB) phục vụ game Web
FROM nginx:1.27-alpine

# Xóa cấu hình và file HTML mặc định của Nginx
RUN rm -rf /etc/nginx/conf.d/* /usr/share/nginx/html/*

# Chép cấu hình Nginx tối ưu cho Godot 4 Web (COOP/COEP, MIME types, cache, gzip)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Chép toàn bộ file build Web (index.html, index.js, index.wasm, index.pck,...)
COPY dist/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD wget -qO- http://127.0.0.1/index.html > /dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
