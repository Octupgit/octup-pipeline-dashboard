FROM nginx:alpine

# Copy the dashboard into nginx's default html directory
COPY octup-pipeline-dashboard.html /usr/share/nginx/html/index.html

# Nginx config: listen on $PORT (Cloud Run injects this)
RUN printf 'server {\n\
    listen $PORT;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
}\n' > /etc/nginx/templates/default.conf.template

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
