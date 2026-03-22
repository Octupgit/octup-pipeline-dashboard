FROM nginx:alpine

# Copy the dashboard as the root index
COPY octup-pipeline-dashboard.html /usr/share/nginx/html/index.html

# Write a simple nginx config listening on 8080 (Cloud Run default)
RUN mkdir -p /etc/nginx/conf.d && \
    printf 'server {\n    listen 8080;\n    root /usr/share/nginx/html;\n    index index.html;\n    location / {\n        try_files $uri $uri/ /index.html;\n    }\n}\n' \
    > /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
