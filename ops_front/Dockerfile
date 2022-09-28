FROM node:lts-alpine as build
WORKDIR /ops
ENV PATH /ops/node_modules/.bin:$PATH
COPY package.json ./
RUN npm install -g npm@8.19.1
RUN npm i --silent
COPY . ./

RUN npm run build

FROM nginx:1.21
RUN apt-get update \
    && apt-get install -y wget \
    && rm -rf /var/lib/apt/lists/*
RUN rm -rf /usr/share/nginx/html/*
COPY --from=build /ops/nginx/nginx.conf /etc/nginx/conf.d/default.conf:ro
COPY --from=build /ops/dist /usr/share/nginx/html